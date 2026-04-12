import { useState } from 'react';
import type { CreateReservationInput } from '../lib/apiClient';

interface ReservationFormProps {
  onSubmit: (input: CreateReservationInput) => Promise<void>;
  submitting?: boolean;
}

const inputStyle: React.CSSProperties = {
  width: '100%',
  padding: '10px 14px',
  borderRadius: '6px',
  border: '1px solid #dee2e6',
  fontSize: '1rem',
  outline: 'none',
  boxSizing: 'border-box',
};

const labelStyle: React.CSSProperties = {
  display: 'block',
  marginBottom: '6px',
  fontWeight: 600,
  color: '#444',
  fontSize: '0.9rem',
};

const fieldStyle: React.CSSProperties = {
  marginBottom: '20px',
};

export default function ReservationForm({ onSubmit, submitting = false }: ReservationFormProps) {
  const [form, setForm] = useState<CreateReservationInput>({
    guestName: '',
    guestEmail: '',
    checkIn: '',
    checkOut: '',
    roomType: 'standard',
  });

  const [errors, setErrors] = useState<Partial<Record<keyof CreateReservationInput, string>>>({});

  const validate = (): boolean => {
    const newErrors: Partial<Record<keyof CreateReservationInput, string>> = {};
    if (!form.guestName.trim()) newErrors.guestName = 'Guest name is required';
    if (!form.guestEmail.trim()) newErrors.guestEmail = 'Email is required';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.guestEmail)) newErrors.guestEmail = 'Invalid email address';
    if (!form.checkIn) newErrors.checkIn = 'Check-in date is required';
    if (!form.checkOut) newErrors.checkOut = 'Check-out date is required';
    if (form.checkIn && form.checkOut && form.checkOut <= form.checkIn) {
      newErrors.checkOut = 'Check-out must be after check-in';
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setForm(prev => ({ ...prev, [name]: value }));
    if (errors[name as keyof CreateReservationInput]) {
      setErrors(prev => ({ ...prev, [name]: undefined }));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;
    await onSubmit(form);
    setForm({ guestName: '', guestEmail: '', checkIn: '', checkOut: '', roomType: 'standard' });
  };

  const today = new Date().toISOString().split('T')[0];

  return (
    <form onSubmit={handleSubmit} noValidate>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0 24px' }}>
        <div style={fieldStyle}>
          <label style={labelStyle} htmlFor="guestName">Guest Name *</label>
          <input
            id="guestName"
            name="guestName"
            type="text"
            value={form.guestName}
            onChange={handleChange}
            placeholder="John Smith"
            style={{ ...inputStyle, borderColor: errors.guestName ? '#dc3545' : '#dee2e6' }}
          />
          {errors.guestName && <p style={{ color: '#dc3545', fontSize: '0.8rem', margin: '4px 0 0' }}>{errors.guestName}</p>}
        </div>

        <div style={fieldStyle}>
          <label style={labelStyle} htmlFor="guestEmail">Email Address *</label>
          <input
            id="guestEmail"
            name="guestEmail"
            type="email"
            value={form.guestEmail}
            onChange={handleChange}
            placeholder="john@example.com"
            style={{ ...inputStyle, borderColor: errors.guestEmail ? '#dc3545' : '#dee2e6' }}
          />
          {errors.guestEmail && <p style={{ color: '#dc3545', fontSize: '0.8rem', margin: '4px 0 0' }}>{errors.guestEmail}</p>}
        </div>

        <div style={fieldStyle}>
          <label style={labelStyle} htmlFor="checkIn">Check-in Date *</label>
          <input
            id="checkIn"
            name="checkIn"
            type="date"
            value={form.checkIn}
            onChange={handleChange}
            min={today}
            style={{ ...inputStyle, borderColor: errors.checkIn ? '#dc3545' : '#dee2e6' }}
          />
          {errors.checkIn && <p style={{ color: '#dc3545', fontSize: '0.8rem', margin: '4px 0 0' }}>{errors.checkIn}</p>}
        </div>

        <div style={fieldStyle}>
          <label style={labelStyle} htmlFor="checkOut">Check-out Date *</label>
          <input
            id="checkOut"
            name="checkOut"
            type="date"
            value={form.checkOut}
            onChange={handleChange}
            min={form.checkIn || today}
            style={{ ...inputStyle, borderColor: errors.checkOut ? '#dc3545' : '#dee2e6' }}
          />
          {errors.checkOut && <p style={{ color: '#dc3545', fontSize: '0.8rem', margin: '4px 0 0' }}>{errors.checkOut}</p>}
        </div>
      </div>

      <div style={fieldStyle}>
        <label style={labelStyle} htmlFor="roomType">Room Type</label>
        <select
          id="roomType"
          name="roomType"
          value={form.roomType}
          onChange={handleChange}
          style={inputStyle}
        >
          <option value="standard">Standard Room — $89/night</option>
          <option value="deluxe">Deluxe Room — $129/night</option>
          <option value="suite">Suite — $189/night</option>
        </select>
      </div>

      <button
        type="submit"
        disabled={submitting}
        style={{
          background: submitting ? '#adb5bd' : 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          color: 'white',
          border: 'none',
          padding: '12px 32px',
          borderRadius: '8px',
          cursor: submitting ? 'not-allowed' : 'pointer',
          fontWeight: 700,
          fontSize: '1rem',
          width: '100%',
        }}
      >
        {submitting ? 'Creating Reservation...' : 'Confirm Reservation'}
      </button>
    </form>
  );
}
