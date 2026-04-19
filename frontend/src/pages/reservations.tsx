import Head from 'next/head';
import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import Layout from '../components/Layout';
import ReservationForm from '../components/ReservationForm';
import ReservationCard from '../components/reservations/ReservationCard';
import PageSectionHeader from '../components/ui/PageSectionHeader';
import { Notice, StatusPanel } from '../components/ui/StatusPanel';
import { getReservations, createReservation, deleteReservation, type Reservation, type CreateReservationInput } from '../lib/apiClient';
import { BRAND } from '../lib/brand';
import withAdminAuth from '../components/auth/withAdminAuth';

function ReservationsPage(): JSX.Element {
  const { t } = useTranslation();
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [showForm, setShowForm] = useState(false);

  const fetchReservations = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getReservations();
      setReservations(data);
    } catch {
      setError(t('reservations.errorLoad'));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    fetchReservations();
  }, [fetchReservations]);

  const handleCreate = async (input: CreateReservationInput) => {
    setCreating(true);
    try {
      const newReservation = await createReservation(input);
      setReservations(prev => [newReservation, ...prev]);
      setShowForm(false);
    } catch {
      setError(t('reservations.errorCreate'));
    } finally {
      setCreating(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm(t('reservations.confirmCancel'))) return;
    try {
      await deleteReservation(id);
      setReservations(prev => prev.filter(r => r.id !== id));
    } catch {
      setError(t('reservations.errorDelete'));
    }
  };

  return (
    <Layout>
      <Head>
        <title>{`${t('reservations.pageTitle')} | ${BRAND.fullName}`}</title>
        <meta name="description" content={`${t('reservations.planYourStay')} - ${BRAND.fullName}.`} />
      </Head>

      <section className="section-inner reservations-page">
        <PageSectionHeader
          kicker={t('reservations.pageTitle')}
          title={t('reservations.planYourStay')}
          subtitle={t('reservations.subtitle')}
          action={
            <button
              type="button"
              onClick={() => setShowForm((prev) => !prev)}
              className="reservations-new-btn"
            >
              {showForm ? t('reservations.closeForm') : t('reservations.newReservation')}
            </button>
          }
        />

        {showForm ? (
          <section className="reservation-form-panel" aria-labelledby="new-reservation-title">
            <h2 id="new-reservation-title" className="reservation-form-panel__title">
              {t('reservations.createReservation')}
            </h2>
            <ReservationForm onSubmit={handleCreate} submitting={creating} />
          </section>
        ) : null}

        {error ? <Notice message={error} /> : null}

        {loading ? (
          <StatusPanel
            icon="⏳"
            title={t('reservations.loadingTitle')}
            description={t('reservations.loadingDesc')}
          />
        ) : reservations.length === 0 ? (
          <StatusPanel
            icon="📋"
            title={t('reservations.emptyTitle')}
            description={t('reservations.emptyDesc')}
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

export default withAdminAuth(ReservationsPage);
