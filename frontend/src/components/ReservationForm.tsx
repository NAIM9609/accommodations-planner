import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { CreateReservationInput } from '../lib/apiClient';
import FormField from './ui/FormField';

interface ReservationFormProps {
  onSubmit: (input: CreateReservationInput) => Promise<void>;
  submitting?: boolean;
}

export default function ReservationForm({ onSubmit, submitting = false }: ReservationFormProps) {
  const { t } = useTranslation();

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
    if (!form.guestName.trim()) newErrors.guestName = t('form.errors.guestNameRequired');
    if (!form.guestEmail.trim()) newErrors.guestEmail = t('form.errors.emailRequired');
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.guestEmail)) newErrors.guestEmail = t('form.errors.emailInvalid');
    if (!form.checkIn) newErrors.checkIn = t('form.errors.checkInRequired');
    if (!form.checkOut) newErrors.checkOut = t('form.errors.checkOutRequired');
    if (form.checkIn && form.checkOut && form.checkOut <= form.checkIn) {
      newErrors.checkOut = t('form.errors.checkOutAfterCheckIn');
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
          label={t('form.guestName')}
          required
          value={form.guestName}
          onChange={handleChange}
          placeholder={t('form.guestNamePlaceholder')}
          error={errors.guestName}
        />

        <FormField
          id="guestEmail"
          name="guestEmail"
          label={t('form.emailAddress')}
          required
          type="email"
          value={form.guestEmail}
          onChange={handleChange}
          placeholder={t('form.emailPlaceholder')}
          error={errors.guestEmail}
        />

        <FormField
          id="checkIn"
          name="checkIn"
          label={t('form.checkInDate')}
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
          label={t('form.checkOutDate')}
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
        label={t('form.roomType')}
        as="select"
        value={form.roomType}
        onChange={handleChange}
        options={[
          { value: 'standard', label: t('form.standardRoom') },
          { value: 'deluxe', label: t('form.deluxeRoom') },
          { value: 'suite', label: t('form.suiteRoom') },
        ]}
      />

      <button
        type="submit"
        disabled={submitting}
        className={`reservation-form__submit${submitting ? ' reservation-form__submit--disabled' : ''}`}
      >
        {submitting ? t('form.creatingReservation') : t('form.confirmReservation')}
      </button>
    </form>
  );
}
