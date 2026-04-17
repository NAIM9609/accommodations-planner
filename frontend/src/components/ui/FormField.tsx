import type { ChangeEvent } from 'react';

type FormFieldChangeEvent = ChangeEvent<HTMLInputElement | HTMLSelectElement>;

interface SelectOption {
  value: string;
  label: string;
}

interface FormFieldProps {
  id: string;
  name: string;
  label: string;
  required?: boolean;
  value: string;
  onChange: (e: FormFieldChangeEvent) => void;
  error?: string;
  as?: 'input' | 'select';
  type?: 'text' | 'email' | 'date';
  placeholder?: string;
  min?: string;
  options?: SelectOption[];
}

export default function FormField({
  id,
  name,
  label,
  required = false,
  value,
  onChange,
  error,
  as = 'input',
  type = 'text',
  placeholder,
  min,
  options,
}: FormFieldProps): JSX.Element {
  const describedBy = error ? `${id}-error` : undefined;
  const className = `reservation-form__input${error ? ' reservation-form__input--error' : ''}`;

  return (
    <div className="reservation-form__field">
      <label className="reservation-form__label" htmlFor={id}>
        {label} {required ? <span aria-hidden="true">*</span> : null}
      </label>

      {as === 'select' ? (
        <select
          id={id}
          name={name}
          value={value}
          onChange={onChange}
          aria-invalid={error ? 'true' : 'false'}
          aria-describedby={describedBy}
          className={className}
        >
          {options?.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      ) : (
        <input
          id={id}
          name={name}
          type={type}
          value={value}
          onChange={onChange}
          min={min}
          placeholder={placeholder}
          aria-invalid={error ? 'true' : 'false'}
          aria-describedby={describedBy}
          className={className}
        />
      )}

      {error ? (
        <p id={describedBy} className="reservation-form__error">
          {error}
        </p>
      ) : null}
    </div>
  );
}
