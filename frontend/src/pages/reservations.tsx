import Head from 'next/head';
import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import ReservationForm from '../components/ReservationForm';
import ReservationCard from '../components/reservations/ReservationCard';
import PageSectionHeader from '../components/ui/PageSectionHeader';
import { Notice, StatusPanel } from '../components/ui/StatusPanel';
import { getReservations, createReservation, deleteReservation, type Reservation, type CreateReservationInput } from '../lib/apiClient';
import { BRAND } from '../lib/brand';

function ReservationsPage(): JSX.Element {
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [showForm, setShowForm] = useState(false);

  const fetchReservations = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getReservations();
      setReservations(data);
    } catch {
      setError('Failed to load reservations. Please check your API configuration.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchReservations();
  }, []);

  const handleCreate = async (input: CreateReservationInput) => {
    setCreating(true);
    try {
      const newReservation = await createReservation(input);
      setReservations(prev => [newReservation, ...prev]);
      setShowForm(false);
    } catch {
      setError('Failed to create reservation. Please try again.');
    } finally {
      setCreating(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to cancel this reservation?')) return;
    try {
      await deleteReservation(id);
      setReservations(prev => prev.filter(r => r.id !== id));
    } catch {
      setError('Failed to delete reservation. Please try again.');
    }
  };

  return (
    <Layout>
      <Head>
        <title>{`Reservations | ${BRAND.fullName}`}</title>
        <meta name="description" content={`Create and manage reservations at ${BRAND.fullName}.`} />
      </Head>

      <section className="section-inner reservations-page">
        <PageSectionHeader
          kicker="Reservations"
          title="Plan your stay"
          subtitle="Create new bookings, review active stays, and manage availability from one place."
          action={
            <button
              type="button"
              onClick={() => setShowForm((prev) => !prev)}
              className="reservations-new-btn"
            >
              {showForm ? 'Close Form' : 'New Reservation'}
            </button>
          }
        />

        {showForm ? (
          <section className="reservation-form-panel" aria-labelledby="new-reservation-title">
            <h2 id="new-reservation-title" className="reservation-form-panel__title">
              Create a reservation
            </h2>
            <ReservationForm onSubmit={handleCreate} submitting={creating} />
          </section>
        ) : null}

        {error ? <Notice message={error} /> : null}

        {loading ? (
          <StatusPanel
            icon="⏳"
            title="Loading reservations"
            description="Gathering the latest bookings and availability details."
          />
        ) : reservations.length === 0 ? (
          <StatusPanel
            icon="📋"
            title="No reservations yet"
            description="Create your first reservation to begin managing guest stays."
          />
        ) : (
          <div className="reservation-list">
            {reservations.map(r => (
              <ReservationCard key={r.id} reservation={r} onCancel={handleDelete} />
            ))}
          </div>
        )}
      </section>
    </Layout>
  );
}

export default ReservationsPage;
