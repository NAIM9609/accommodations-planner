import type { ReactNode } from 'react';

interface PageSectionHeaderProps {
  kicker?: string;
  title: string;
  subtitle?: string;
  action?: ReactNode;
}

export default function PageSectionHeader({
  kicker,
  title,
  subtitle,
  action,
}: PageSectionHeaderProps): JSX.Element {
  return (
    <header className="page-section-header">
      <div>
        {kicker ? <p className="lux-kicker">{kicker}</p> : null}
        <h1 className="lux-heading page-section-header__title">{title}</h1>
        {subtitle ? <p className="page-section-header__subtitle">{subtitle}</p> : null}
      </div>
      {action ? <div className="page-section-header__action">{action}</div> : null}
    </header>
  );
}
