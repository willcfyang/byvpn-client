import { useTranslation } from 'react-i18next';
import { ButtonNew } from '../../../ui';

type Props = {
  onSignup: () => void;
  onLogin: () => void;
};

export function LabWelcome({ onSignup, onLogin }: Props) {
  const { t } = useTranslation('login');
  return (
    <div className="flex h-full flex-col items-center justify-between gap-6">
      <div className="flex flex-col items-center gap-2">
        <h1 className="text-text-primary text-2xl font-medium tracking-tight">
          {t('lab.welcome.title')}
        </h1>
        <p className="text-bombay w-[281px] text-center text-sm">
          {t('lab.welcome.description')}
        </p>
      </div>
      <div className="flex w-full flex-col gap-3">
        <ButtonNew onClick={onSignup}>{t('lab.register.button')}</ButtonNew>
        <ButtonNew onClick={onLogin}>{t('lab.login.button')}</ButtonNew>
      </div>
    </div>
  );
}
