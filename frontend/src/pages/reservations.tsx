import Head from 'next/head';
import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import ReservationForm from '../components/ReservationForm';
import { getReservations, createReservation, deleteReservation, type Reservation, type CreateReservationInput } from '../lib/apiClient';

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

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
  };

  const roomBadgeColor: Record<string, string> = {
    standard: '#6c757d',
    deluxe: '#0d6efd',
    suite: '#6f42c1',
  };

  return (
    <Layout>
      <Head>
        <title>Reservations - Maple Grove B&B</title>
        <meta name="description" content="Manage your reservations at Maple Grove B&B" />
      </Head>

      <div style={{ maxWidth: 900, margin: '0 auto', padding: '24px 16px' }}>
        <div className="reservations-header">
          <div>
            <h1 style={{ fontSize: 'clamp(1.4rem, 4vw, 2rem)', color: '#333', margin: 0 }}>Reservations</h1>
            <p style={{ color: '#666', margin: '8px 0 0' }}>Manage all B&amp;B reservations</p>
          </div>
          <button
            onClick={() => setShowForm(!showForm)}
            className="reservations-new-btn"
          >
            {showForm ? '✕ Cancel' : '+ New Reservation'}
          </button>
        </div>

        {showForm && (
          <div style={{
            background: 'white',
            borderRadius: '12px',
            padding: '32px',
            boxShadow: '0 4px 20px rgba(0,0,0,0.1)',
            marginBottom: '32px',
            border: '2px solid #667eea',
          }}>
            <h2 style={{ margin: '0 0 24px', color: '#333' }}>New Reservation</h2>
            <ReservationForm onSubmit={handleCreate} submitting={creating} />
          </div>
        )}

        {error && (
          <div style={{
            background: '#fff3cd',
            border: '1px solid #ffc107',
            borderRadius: '8px',
            padding: '16px',
            marginBottom: '24px',
            color: '#856404',
          }}>
            ⚠️ {error}
          </div>
        )}

        {loading ? (
          <div style={{ textAlign: 'center', padding: '60px', color: '#666' }}>
            <div style={{ fontSize: '2rem', marginBottom: '16px' }}>⏳</div>
            <p>Loading reservations...</p>
          </div>
        ) : reservations.length === 0 ? (
          <div style={{
            textAlign: 'center',
            padding: '60px',
            background: 'white',
            borderRadius: '12px',
            boxShadow: '0 4px 20px rgba(0,0,0,0.05)',
          }}>
            <div style={{ fontSize: '3rem', marginBottom: '16px' }}>📋</div>
            <h3 style={{ color: '#333', marginBottom: '8px' }}>No reservations yet</h3>
            <p style={{ color: '#666' }}>Click &ldquo;New Reservation&rdquo; to create the first one.</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            {reservations.map(r => (
              <div key={r.id} className="reservation-card">
                <div className="reservation-card__info">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px', flexWrap: 'wrap' }}>
                    <h3 style={{ margin: 0, color: '#333', fontSize: '1.1rem' }}>{r.guestName}</h3>
                    <span style={{
                      background: roomBadgeColor[r.roomType] ?? '#6c757d',
                      color: 'white',
                      padding: '2px 10px',
                      borderRadius: '12px',
                      fontSize: '0.75rem',
                      fontWeight: 600,
                      textTransform: 'capitalize',
                    }}>
                      {r.roomType}
                    </span>
                  </div>
                  <p style={{ margin: '0 0 6px', color: '#666', fontSize: '0.9rem' }}>
                    📧 {r.guestEmail}
                  </p>
                  <p style={{ margin: '0 0 6px', color: '#666', fontSize: '0.9rem' }}>
                    📅 {formatDate(r.checkIn)} → {formatDate(r.checkOut)}
                  </p>
                  <p style={{ margin: 0, color: '#999', fontSize: '0.8rem' }}>
                    ID: {r.id} · Booked: {new Date(r.createdAt).toLocaleDateString()}
                  </p>
                </div>
                <div className="reservation-card__actions">
                  <button
                    onClick={() => handleDelete(r.id)}
                    style={{
                      background: 'none',
                      border: '1px solid #dc3545',
                      color: '#dc3545',
                      padding: '8px 16px',
                      borderRadius: '6px',
                      cursor: 'pointer',
                      fontWeight: 600,
                      fontSize: '0.85rem',
                      whiteSpace: 'nowrap',
                      minHeight: '40px',
                    }}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </Layout>
  );
}

export default ReservationsPage;
