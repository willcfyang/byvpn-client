import { useState } from 'react';
import { useShallow } from 'zustand/react/shallow';
import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { invoke } from '@tauri-apps/api/core';
import clsx from 'clsx';
import { dispatch, useAppStore } from '../../../store/index';
import { useToast } from '../../../hooks/index';
import { BackendError, TAccountMode } from '../../../types/index';
import { routes } from '../../../router';
import { CCache } from '../../../cache/index';
import { ButtonNew, TextInput } from '../../../ui';

const LAB_DNS = ['8.8.8.8', '1.1.1.1'];

type Mode = 'login' | 'register';

type Props = {
  mode: Mode;
  onRegistered?: () => void;
};

function errorDetail(e: unknown): string {
  const be = e as BackendError;
  const details = be?.data?.details;
  if (typeof details === 'string' && details.length > 0) return details;
  if (typeof be?.message === 'string' && be.message.length > 0) return be.message;
  return '';
}

export function LabAuthForm({ mode, onRegistered }: Props) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const { add, close } = useToast();
  const { daemonStatus, state, technicalOptinSeen } = useAppStore(
    useShallow((s) => ({
      daemonStatus: s.daemonStatus,
      state: s.state,
      technicalOptinSeen: s.technicalOptinSeen,
    })),
  );

  const navigate = useNavigate();
  const { t } = useTranslation('login');

  const refreshAccountMode = async () => {
    const accountMode = await invoke<TAccountMode>('get_account_mode');
    dispatch({ type: 'set-account-mode', mode: accountMode });
  };

  const applyLabDns = async () => {
    try {
      await invoke('set_custom_dns', { dns: LAB_DNS });
      await invoke('set_custom_dns_enabled', { enabled: true });
      dispatch({ type: 'set-custom-dns', dns: LAB_DNS });
      dispatch({ type: 'set-custom-dns-enabled', enabled: true });
    } catch (e) {
      console.warn('[lab-auth] failed to set lab DNS', e);
    }
  };

  const handleRegister = async () => {
    if (loading || !username.trim() || !password) return;
    if (password.length < 8) {
      setError(t('lab.error.password-short'));
      return;
    }
    if (password !== confirmPassword) {
      setError(t('lab.error.password-mismatch'));
      return;
    }

    setLoading(true);
    setError('');
    try {
      await invoke('lab_auth_register', {
        username: username.trim(),
        password,
      });
      add({
        id: 'lab-register-ok',
        title: t('lab.register.success'),
        type: 'success',
      });
      setPassword('');
      setConfirmPassword('');
      onRegistered?.();
    } catch (e: unknown) {
      console.error('[lab-auth] register', e);
      const detail = errorDetail(e).toLowerCase();
      let msg = t('lab.error.register-failed');
      if (detail.includes('taken') || detail.includes('conflict') || detail.includes('exist')) {
        msg = t('lab.error.username-taken');
      } else if (errorDetail(e)) {
        msg = errorDetail(e);
      }
      setError(msg);
      add({ id: 'lab-register-err', title: msg, type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async () => {
    if (loading || !username.trim() || !password) return;

    if (state !== 'disconnected') {
      add({
        id: 'tunnel-running-login-error',
        title: t('login.can-t-login-while-tunnel-is-running'),
        type: 'error',
      });
      return;
    }

    setLoading(true);
    setError('');
    try {
      const mnemonic = await invoke<string>('lab_auth_login', {
        username: username.trim(),
        password,
      });
      await invoke('add_account', { mnemonic: mnemonic.trim() });
      await applyLabDns();

      dispatch({ type: 'set-account', stored: true });
      await refreshAccountMode();
      await CCache.del('cache-account-id');
      await CCache.del('cache-device-id');
      dispatch({ type: 'reset-error' });

      close('tunnel-running-login-error');
      if (!technicalOptinSeen) {
        navigate(routes.technicalOptin);
      } else {
        navigate(routes.root);
      }
    } catch (e: unknown) {
      console.error('[lab-auth] login', e);
      const detail = errorDetail(e).toLowerCase();
      let msg = t('lab.error.login-failed');
      if (
        detail.includes('invalid') ||
        detail.includes('unauthorized') ||
        detail.includes('401')
      ) {
        msg = t('lab.error.invalid-credentials');
      } else if (errorDetail(e)) {
        msg = errorDetail(e);
      }
      setError(msg);
      add({ id: 'lab-login-err', title: msg, type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const title =
    mode === 'login' ? t('lab.login.title') : t('lab.register.title');
  const submitLabel =
    mode === 'login' ? t('lab.login.button') : t('lab.register.button');
  const onSubmit = mode === 'login' ? handleLogin : handleRegister;

  return (
    <div className="flex h-full flex-col items-center justify-between gap-6">
      <div className="flex flex-col items-center gap-2">
        <h1 className="text-text-primary text-2xl font-medium tracking-tight">
          {title}
        </h1>
      </div>
      <div className="flex w-full flex-col gap-3">
        <TextInput
          value={username}
          onChange={(v) => {
            setUsername(v);
            setError('');
          }}
          placeholder={t('lab.username')}
          spellCheck={false}
          disabled={loading}
        />
        <TextInput
          type="password"
          value={password}
          onChange={(v) => {
            setPassword(v);
            setError('');
          }}
          placeholder={t('lab.password')}
          spellCheck={false}
          disabled={loading}
        />
        {mode === 'register' && (
          <TextInput
            type="password"
            value={confirmPassword}
            onChange={(v) => {
              setConfirmPassword(v);
              setError('');
            }}
            placeholder={t('lab.confirm-password')}
            spellCheck={false}
            disabled={loading}
          />
        )}
        {error && (
          <p className={clsx('text-aphrodisiac text-center text-xs')}>{error}</p>
        )}
        <ButtonNew
          onClick={onSubmit}
          loading={loading}
          disabled={
            daemonStatus === 'down' ||
            (mode === 'login' && state !== 'disconnected')
          }
        >
          {submitLabel}
        </ButtonNew>
      </div>
    </div>
  );
}
