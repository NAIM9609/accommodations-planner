import { useState } from 'react';
import type { CreateReservationInput } from '../lib/apiClient';
import FormField from './ui/FormField';

interface ReservationFormProps {
  onSubmit: (input: CreateReservationInput) => Promise<void>;
  submitting?: boolean;
}

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
    <form onSubmit={handleSubmit} noValidate className="reservation-form">
      <div className="form-grid">
        <FormField
          id="guestName"
          name="guestName"
          label="Guest Name"
          required
          value={form.guestName}
          onChange={handleChange}
          placeholder="John Smith"
          error={errors.guestName}
        />

        <FormField
          id="guestEmail"
          name="guestEmail"
          label="Email Address"
          required
          type="email"
          value={form.guestEmail}
          onChange={handleChange}
          placeholder="john@example.com"
          error={errors.guestEmail}
        />

        <FormField
          id="checkIn"
          name="checkIn"
          label="Check-in Date"
          required
          type="date"
          value={form.checkIn}
          onChange={handleChange}
          min={today}
          error={errors.checkIn}
        />

        <FormField
          id="checkOut"
          name="checkOut"
          label="Check-out Date"
          required
          type="date"
          value={form.checkOut}
          onChange={handleChange}
          min={form.checkIn || today}
          error={errors.checkOut}
        />
      </div>

      <FormField
        id="roomType"
        name="roomType"
        label="Room Type"
        as="select"
        value={form.roomType}
        onChange={handleChange}
        options={[
          { value: 'standard', label: 'Standard Room - $89/night' },
          { value: 'deluxe', label: 'Deluxe Room - $129/night' },
          { value: 'suite', label: 'Suite - $189/night' },
        ]}
      />

      <button
        type="submit"
        disabled={submitting}
        className={`reservation-form__submit${submitting ? ' reservation-form__submit--disabled' : ''}`}
      >
        {submitting ? 'Creating Reservation...' : 'Confirm Reservation'}
      </button>
    </form>
  );
}
