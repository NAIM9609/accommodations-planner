import type { Reservation } from '../../lib/apiClient';

interface ReservationCardProps {
  reservation: Reservation;
  onCancel: (id: string) => void;
}

const roomTypeLabel: Record<Reservation['roomType'], string> = {
  standard: 'Standard',
  deluxe: 'Deluxe',
  suite: 'Suite',
};

const formatDate = (dateStr: string): string => (
  new Date(dateStr).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
);

export default function ReservationCard({ reservation, onCancel }: ReservationCardProps): JSX.Element {
  return (
    <article className="reservation-card reservation-card--luxury">
      <div className="reservation-card__info">
        <div className="reservation-card__head">
          <h3>{reservation.guestName}</h3>
          <span className={`reservation-badge reservation-badge--${reservation.roomType}`}>
            {roomTypeLabel[reservation.roomType]}
          </span>
        </div>

        <p className="reservation-card__line">Email: {reservation.guestEmail}</p>
        <p className="reservation-card__line">
          Stay: {formatDate(reservation.checkIn)} - {formatDate(reservation.checkOut)}
        </p>
        <p className="reservation-card__meta">
          ID: {reservation.id} | Booked: {formatDate(reservation.createdAt)}
        </p>
      </div>

      <div className="reservation-card__actions">
        <button
          type="button"
          onClick={() => onCancel(reservation.id)}
          className="reservation-cancel-btn"
        >
          Cancel Reservation
        </button>
      </div>
    </article>
  );
}
