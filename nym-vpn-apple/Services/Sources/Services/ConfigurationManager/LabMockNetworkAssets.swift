import Foundation

enum LabMockNetworkAssets {
    static let discoveryJSON = """
{
  "updated_at": "2026-05-24 20:20:00.253581825",
  "value": {
    "network_name": "mainnet",
    "nym_api_url": "http://104.250.122.199:8088/api/",
    "nym_api_urls": [
      {
        "url": "http://104.250.122.199:8088/api/",
        "fronts": null
      }
    ],
    "nym_vpn_api_url": "http://104.250.122.199:8088/api/",
    "nym_vpn_api_urls": [
      {
        "url": "http://104.250.122.199:8088/api/",
        "fronts": null
      }
    ],
    "account_management": null,
    "feature_flags": {
      "domain_fronting": {
        "enabled": "false"
      },
      "zkNyms": {
        "credentialMode": "false"
      },
      "privy": {
        "enabled": "false"
      },
      "quic": {
        "enabled": "false"
      }
    },
    "system_configuration": {
      "mix_thresholds": {
        "high": 75,
        "medium": 50,
        "low": 25
      },
      "wg_thresholds": {
        "high": 75,
        "medium": 50,
        "low": 25
      },
      "statistics_api": null,
      "min_supported_app_versions": null
    },
    "system_messages": []
  }
}
"""
    static let mainnetJSON = """
{
  "updated_at": "2026-05-24 20:20:00.425635539",
  "value": {
    "network_name": "mainnet",
    "chain_details": {
      "bech32_account_prefix": "n",
      "mix_denom": {
        "base": "unym",
        "display": "nym",
        "display_exponent": 6
      },
      "stake_denom": {
        "base": "unyx",
        "display": "nyx",
        "display_exponent": 6
      }
    },
    "endpoints": [
      {
        "nyxd_url": "https://rpc.nymtech.net/",
        "websocket_url": "wss://rpc.nymtech.net/websocket",
        "api_url": "http://104.250.122.199:8088/api"
      }
    ],
    "contracts": {
      "mixnet_contract_address": "n17srjznxl9dvzdkpwpw24gg668wc73val88a6m5ajg6ankwvz9wtst0cznr",
      "vesting_contract_address": "n1nc5tatafv6eyq7llkr2gv50ff9e22mnf70qgjlv737ktmt4eswrq73f2nw",
      "performance_contract_address": null,
      "ecash_contract_address": "n1r7s6aksyc6pqardx88k3rkgfagwvj4z4zum9mmz2sfk3zm2mha0sd4dnun",
      "group_contract_address": "n1e2zq4886zzewpvpucmlw8v9p7zv692f6yck4zjzxh699dkcmlrfqk2knsr",
      "multisig_contract_address": "n1txayqfz5g9qww3rlflpg025xd26m9payz96u54x4fe3s2ktz39xqk67gzx",
      "coconut_dkg_contract_address": "n19604yflqggs9mk2z26mqygq43q2kr3n932egxx630svywd5mpxjsztfpvx"
    },
    "nym_vpn_api_url": null,
    "nym_api_urls": [
      {
        "url": "http://104.250.122.199:8088/api",
        "front_hosts": null
      }
    ],
    "nym_vpn_api_urls": [
      {
        "url": "http://104.250.122.199:8088/api",
        "front_hosts": null
      }
    ]
  }
}
"""
}
