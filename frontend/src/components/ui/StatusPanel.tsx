import { useTranslation } from 'react-i18next';

interface StatusPanelProps {
  icon: string;
  title: string;
  description: string;
}

export function StatusPanel({ icon, title, description }: StatusPanelProps): JSX.Element {
  return (
    <section className="status-panel" aria-live="polite">
      <p className="status-panel__icon" aria-hidden="true">{icon}</p>
      <h2 className="status-panel__title">{title}</h2>
      <p className="status-panel__description">{description}</p>
    </section>
  );
}

interface NoticeProps {
  message: string;
}

export function Notice({ message }: NoticeProps): JSX.Element {
  const { t } = useTranslation();

  return (
    <div className="notice notice--warning" role="alert">
      <strong className="notice__label">{t('common.notice')}</strong> {message}
    </div>
  );
}
