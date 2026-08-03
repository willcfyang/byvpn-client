// Ecash zk-nym issuance for private-cluster testing (from nym-vpn-account-controller MockCredentialProxy).

use std::{
    collections::HashMap,
    str::FromStr,
    sync::Mutex,
};

use anyhow::{Context, Result};
use nym_compact_ecash::scheme::{
    coin_indices_signatures::{aggregate_annotated_indices_signatures, sign_coin_indices},
    expiration_date_signatures::{aggregate_annotated_expiration_signatures, sign_expiration_date},
};
use nym_compact_ecash::{
    Base58, EncodedDate, KeyPairAuth, PublicKeyUser, SecretKeyAuth, VerificationKeyAuth,
    WithdrawalRequest, aggregate_verification_keys, constants, issue, scheme::keygen::ttp_keygen,
    setup::Parameters,
};
use nym_credential_proxy_requests::api::v1::ticketbook::models::{
    AggregatedCoinIndicesSignaturesResponse, AggregatedExpirationDateSignaturesResponse,
    MasterVerificationKeyResponse, PartialVerificationKey, PartialVerificationKeysResponse,
    TicketbookWalletSharesResponse, WalletShare,
};
use nym_credentials::{AggregatedCoinIndicesSignatures, AggregatedExpirationDateSignatures};
use nym_credentials_interface::{
    AnnotatedCoinIndexSignature, AnnotatedExpirationDateSignature, CoinIndexSignatureShare,
    ExpirationDateSignatureShare, TicketType,
};
use nym_ecash_time::EcashTime;
use nym_vpn_api_client::{
    request::RequestZkNymRequestBody,
    response::{NymVpnZkNym, NymVpnZkNymPost, NymVpnZkNymResponse, NymVpnZkNymStatus, StatusOk},
};
use rand::distributions::{Alphanumeric, DistString};
use time::{Date, OffsetDateTime, macros::format_description};

pub struct CredentialSigner {
    epoch_id: u64,
    coin_indices_signatures: Vec<AnnotatedCoinIndexSignature>,
    expiration_date_signatures: Vec<AnnotatedExpirationDateSignature>,
    master_key: VerificationKeyAuth,
    authorities_keypairs: Vec<KeyPairAuth>,
    shares: Mutex<HashMap<String, StoredZknym>>,
}

struct StoredZknym {
    account: String,
    device: String,
    record: NymVpnZkNym,
}

impl CredentialSigner {
    pub fn new() -> Result<Self> {
        let epoch_id = std::env::var("MOCK_EPOCH_ID")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        Self::new_with_epoch(epoch_id)
    }

    fn new_with_epoch(epoch_id: u64) -> Result<Self> {
        // Must match client spend path (`ecash_parameters()` / TICKETBOOK_SIZE == NB_TICKETS).
        let params = Parameters::new(constants::NB_TICKETS);
        let expiration_date = nym_ecash_time::cred_exp_date().ecash_unix_timestamp();

        let authorities_keypairs = ttp_keygen(2, 3).context("ttp_keygen")?;
        let indices: [u64; 3] = [1, 2, 3];
        let secret_keys_authorities: Vec<&SecretKeyAuth> = authorities_keypairs
            .iter()
            .map(|keypair| keypair.secret_key())
            .collect();
        let verification_keys_auth: Vec<VerificationKeyAuth> = authorities_keypairs
            .iter()
            .map(|keypair| keypair.verification_key())
            .collect();

        let verification_key =
            aggregate_verification_keys(&verification_keys_auth, Some(&[1, 2, 3]))?;

        let expiration_date_signatures = generate_expiration_date_signatures(
            expiration_date,
            &secret_keys_authorities,
            &verification_keys_auth,
            &verification_key,
            &indices,
        )?;

        let coin_indices_signatures = generate_coin_indices_signatures(
            &params,
            &secret_keys_authorities,
            &verification_keys_auth,
            &verification_key,
            &indices,
        )?;

        Ok(Self {
            epoch_id,
            coin_indices_signatures,
            expiration_date_signatures,
            master_key: verification_key,
            authorities_keypairs,
            shares: Mutex::new(HashMap::new()),
        })
    }

    pub fn partial_verification_keys(&self) -> PartialVerificationKeysResponse {
        PartialVerificationKeysResponse {
            epoch_id: self.epoch_id,
            keys: self
                .authorities_keypairs
                .iter()
                .map(|k| PartialVerificationKey {
                    node_index: k.index.unwrap(),
                    bs58_encoded_key: k.verification_key().to_bs58(),
                })
                .collect(),
        }
    }

    pub fn request_zknym(
        &self,
        account: &str,
        device: &str,
        body: RequestZkNymRequestBody,
    ) -> Result<NymVpnZkNymPost> {
        let t_type = body.ticketbook_type.clone();
        let id = Alphanumeric.sample_string(&mut rand::thread_rng(), 15);
        let now = OffsetDateTime::now_utc();
        let valid_until = now + time::Duration::days(30);

        let wallet = TicketbookWalletSharesResponse {
            epoch_id: self.epoch_id,
            shares: self.issue_blinded_shares(&body)?,
            master_verification_key: Some(self.master_key_response()),
            aggregated_coin_index_signatures: Some(self.coin_signatures()),
            aggregated_expiration_date_signatures: Some(self.date_signatures()),
        };

        let zk_nym = NymVpnZkNym {
            created_on_utc: now.to_string(),
            last_updated_utc: now.to_string(),
            id: id.clone(),
            ticketbook_type: t_type.clone(),
            valid_until_utc: valid_until.to_string(),
            valid_from_utc: now.to_string(),
            issued_bandwidth_in_gb: 25f64,
            blinded_shares: Some(wallet),
            status: NymVpnZkNymStatus::Active,
            upgrade_mode: None,
        };

        let key = store_key(account, device, &id);
        self.shares.lock().unwrap().insert(
            key,
            StoredZknym {
                account: account.to_string(),
                device: device.to_string(),
                record: zk_nym,
            },
        );

        Ok(NymVpnZkNymPost {
            created_on_utc: now.to_string(),
            last_updated_utc: now.to_string(),
            id,
            ticketbook_type: t_type,
            valid_until_utc: valid_until.to_string(),
            valid_from_utc: now.to_string(),
            issued_bandwidth_in_gb: 25f64,
            blinded_shares: None,
            status: NymVpnZkNymStatus::Pending,
        })
    }

    pub fn get_zknym(&self, account: &str, device: &str, id: &str) -> Option<NymVpnZkNym> {
        self.shares
            .lock()
            .unwrap()
            .get(&store_key(account, device, id))
            .map(|s| s.record.clone())
    }

    pub fn list_available(&self, account: &str, device: &str) -> NymVpnZkNymResponse {
        let items: Vec<_> = self
            .shares
            .lock()
            .unwrap()
            .values()
            .filter(|s| s.account == account && s.device == device)
            .map(|s| s.record.clone())
            .collect();
        let n = items.len() as u64;
        NymVpnZkNymResponse {
            total_items: n,
            page: 0,
            page_size: 10,
            items,
        }
    }

    pub fn list_device_zknym(&self) -> NymVpnZkNymResponse {
        NymVpnZkNymResponse {
            total_items: 0,
            page: 0,
            page_size: 10,
            items: vec![],
        }
    }

    pub fn confirm_download(&self, account: &str, device: &str, id: &str) -> Result<StatusOk> {
        self.shares
            .lock()
            .unwrap()
            .remove(&store_key(account, device, id))
            .context("zknym not found")?;
        Ok(StatusOk {
            status: "ok".to_string(),
        })
    }

    fn issue_blinded_shares(&self, request: &RequestZkNymRequestBody) -> Result<Vec<WalletShare>> {
        let user_key = PublicKeyUser::from_base58_string(&request.ecash_pubkey)?;
        let expiration_date = parse_expiration_date(&request.expiration_date)?;
        let t_type = TicketType::from_str(&request.ticketbook_type)?.encode();
        let req = WithdrawalRequest::try_from_bs58(&request.withdrawal_request)?;
        let mut wallet_blinded_signatures = Vec::new();
        for auth_keypair in &self.authorities_keypairs {
            let blind_signature = issue(
                auth_keypair.secret_key(),
                user_key,
                &req,
                expiration_date,
                t_type,
            );
            wallet_blinded_signatures.push(WalletShare {
                node_index: auth_keypair.index.unwrap(),
                bs58_encoded_share: blind_signature.unwrap().to_bs58(),
            });
        }
        Ok(wallet_blinded_signatures)
    }

    fn coin_signatures(&self) -> AggregatedCoinIndicesSignaturesResponse {
        AggregatedCoinIndicesSignaturesResponse {
            signatures: AggregatedCoinIndicesSignatures {
                epoch_id: self.epoch_id,
                signatures: self.coin_indices_signatures.clone(),
            },
        }
    }

    fn date_signatures(&self) -> AggregatedExpirationDateSignaturesResponse {
        AggregatedExpirationDateSignaturesResponse {
            signatures: AggregatedExpirationDateSignatures {
                epoch_id: self.epoch_id,
                signatures: self.expiration_date_signatures.clone(),
                expiration_date: nym_ecash_time::cred_exp_date().ecash_date(),
            },
        }
    }

    fn master_key_response(&self) -> MasterVerificationKeyResponse {
        MasterVerificationKeyResponse {
            epoch_id: self.epoch_id,
            bs58_encoded_key: self.master_key.to_bs58(),
        }
    }
}

fn store_key(account: &str, device: &str, id: &str) -> String {
    format!("{account}|{device}|{id}")
}

fn parse_expiration_date(s: &str) -> Result<EncodedDate> {
    let format = format_description!("[year]-[month]-[day]");
    if let Ok(d) = Date::parse(s, &format) {
        return Ok(d.ecash_unix_timestamp());
    }
    // Fallback: client may send a longer datetime string; take date prefix.
    if s.len() >= 10 {
        if let Ok(d) = Date::parse(&s[..10], &format) {
            return Ok(d.ecash_unix_timestamp());
        }
    }
    Ok(nym_ecash_time::cred_exp_date().ecash_unix_timestamp())
}

fn generate_expiration_date_signatures(
    expiration_date: EncodedDate,
    secret_keys_authorities: &[&SecretKeyAuth],
    verification_keys_auth: &[VerificationKeyAuth],
    verification_key: &VerificationKeyAuth,
    indices: &[u64],
) -> Result<Vec<AnnotatedExpirationDateSignature>> {
    let mut edt_partial_signatures: Vec<Vec<_>> =
        Vec::with_capacity(constants::CRED_VALIDITY_PERIOD_DAYS as usize);
    for sk_auth in secret_keys_authorities.iter() {
        let sign = sign_expiration_date(sk_auth, expiration_date).unwrap();
        edt_partial_signatures.push(sign);
    }
    let combined_data: Vec<_> = indices
        .iter()
        .zip(
            verification_keys_auth
                .iter()
                .zip(edt_partial_signatures.iter()),
        )
        .map(|(i, (vk, sigs))| ExpirationDateSignatureShare {
            index: *i,
            key: vk.clone(),
            signatures: sigs.clone(),
        })
        .collect();

    Ok(aggregate_annotated_expiration_signatures(
        verification_key,
        expiration_date,
        &combined_data,
    )?)
}

fn generate_coin_indices_signatures(
    params: &Parameters,
    secret_keys_authorities: &[&SecretKeyAuth],
    verification_keys_auth: &[VerificationKeyAuth],
    verification_key: &VerificationKeyAuth,
    indices: &[u64],
) -> Result<Vec<AnnotatedCoinIndexSignature>> {
    let partial_signatures: Vec<Vec<_>> = secret_keys_authorities
        .iter()
        .map(|sk_auth| sign_coin_indices(params, verification_key, sk_auth).unwrap())
        .collect();

    let combined_data: Vec<_> = indices
        .iter()
        .zip(verification_keys_auth.iter().zip(partial_signatures.iter()))
        .map(|(i, (vk, sigs))| CoinIndexSignatureShare {
            index: *i,
            key: vk.clone(),
            signatures: sigs.clone(),
        })
        .collect();

    Ok(aggregate_annotated_indices_signatures(
        params,
        verification_key,
        &combined_data,
    )?)
}
