import { useTranslation } from 'react-i18next';
import type { Reservation } from '../../lib/apiClient';

interface ReservationCardProps {
  reservation: Reservation;
  onCancel: (id: string) => void;
}

const formatDate = (dateStr: string, locale: string): string => (
  new Date(dateStr).toLocaleDateString(locale, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
);

export default function ReservationCard({ reservation, onCancel }: ReservationCardProps): JSX.Element {
  const { t, i18n } = useTranslation();

  const roomTypeLabel: Record<Reservation['roomType'], string> = {
    standard: t('card.standard'),
    deluxe: t('card.deluxe'),
    suite: t('card.suite'),
  };

  return (
    <article className="reservation-card reservation-card--luxury">
      <div className="reservation-card__info">
        <div className="reservation-card__head">
          <h3>{reservation.guestName}</h3>
          <span className={`reservation-badge reservation-badge--${reservation.roomType}`}>
            {roomTypeLabel[reservation.roomType]}
          </span>
        </div>

        <p className="reservation-card__line">{t('card.email')} {reservation.guestEmail}</p>
        <p className="reservation-card__line">
          {t('card.stay')} {formatDate(reservation.checkIn, i18n.language)} - {formatDate(reservation.checkOut, i18n.language)}
        </p>
        <p className="reservation-card__meta">
          {t('card.id')} {reservation.id} | {t('card.booked')} {formatDate(reservation.createdAt, i18n.language)}
        </p>
      </div>

      <div className="reservation-card__actions">
        <button
          type="button"
          onClick={() => onCancel(reservation.id)}
          className="reservation-cancel-btn"
        >
          {t('card.cancelReservation')}
        </button>
      </div>
    </article>
  );
}
