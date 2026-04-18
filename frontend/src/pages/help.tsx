import Head from 'next/head';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import Layout from '../components/Layout';
import PageSectionHeader from '../components/ui/PageSectionHeader';
import { Notice } from '../components/ui/StatusPanel';
import { askQuestion, type RagCitation, type RagResponse } from '../lib/apiClient';
import { BRAND } from '../lib/brand';

interface CitationItemProps {
  citation: RagCitation;
  index: number;
}

function CitationItem({ citation, index }: CitationItemProps): JSX.Element | null {
  const { t } = useTranslation();
  const [expanded, setExpanded] = useState(false);

  if (!citation.references.length) return null;

  return (
    <li className="help-citation">
      <button
        type="button"
        className="help-citation__toggle"
        onClick={() => setExpanded((prev) => !prev)}
        aria-expanded={expanded}
      >
        {t('ai.help.sourceLabel', { index: index + 1 })}
        <span className="help-citation__arrow" aria-hidden="true">
          {expanded ? '▲' : '▼'}
        </span>
      </button>
      {expanded && (
        <ul className="help-citation__refs">
          {citation.references.map((ref, ri) => (
            <li key={ri} className="help-citation__ref">
              {ref.content && <p className="help-citation__ref-text">{ref.content}</p>}
              {ref.location && (
                <p className="help-citation__ref-loc">
                  <span>{t('ai.help.locationLabel')}</span> {ref.location}
                </p>
              )}
            </li>
          ))}
        </ul>
      )}
    </li>
  );
}

export default function HelpPage(): JSX.Element {
  const { t } = useTranslation();
  const [question, setQuestion] = useState('');
  const [result, setResult] = useState<RagResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);

  const handleAsk = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = question.trim();
    if (!trimmed || loading) return;

    setLoading(true);
    setError(null);
    setResult(null);
    setUnavailable(false);

    try {
      const data = await askQuestion(trimmed);
      setResult(data);
    } catch (err) {
      if (err instanceof Error && err.message === 'RAG_UNAVAILABLE') {
        setUnavailable(true);
      } else {
        setError(t('ai.help.errorAsk'));
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout>
      <Head>
        <title>{`${t('ai.help.pageTitle')} | ${BRAND.fullName}`}</title>
        <meta name="description" content={t('ai.help.metaDescription')} />
      </Head>

      <section className="section-inner help-page">
        <PageSectionHeader
          kicker={t('ai.help.kicker')}
          title={t('ai.help.pageTitle')}
          subtitle={t('ai.help.subtitle')}
        />

        {unavailable ? (
          <div className="help-unavailable">
            <p className="help-unavailable__icon" aria-hidden="true">🔧</p>
            <h2 className="help-unavailable__title">{t('ai.help.unavailableTitle')}</h2>
            <p className="help-unavailable__desc">{t('ai.help.unavailableDesc')}</p>
          </div>
        ) : (
          <form className="help-form" onSubmit={handleAsk} noValidate>
            <label htmlFor="help-question" className="help-form__label">
              {t('ai.help.questionLabel')}
            </label>
            <div className="help-form__row">
              <input
                id="help-question"
                type="text"
                className="help-form__input"
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                placeholder={t('ai.help.questionPlaceholder')}
                disabled={loading}
                maxLength={500}
                required
                aria-describedby={error ? 'help-error' : undefined}
              />
              <button
                type="submit"
                className="help-form__submit"
                disabled={loading || !question.trim()}
              >
                {loading ? t('ai.help.askingButton') : t('ai.help.askButton')}
              </button>
            </div>
          </form>
        )}

        {error && <Notice message={error} />}

        {result && (
          <div className="help-result" aria-live="polite">
            <h2 className="help-result__heading">{t('ai.help.answerHeading')}</h2>
            <p className="help-result__answer">{result.answer}</p>

            {result.citations.some((c) => c.references.length > 0) && (
              <div className="help-result__citations">
                <h3 className="help-result__citations-heading">
                  {t('ai.help.citationsHeading')}
                </h3>
                <ul className="help-citations-list">
                  {result.citations.map((citation, i) => (
                    <CitationItem key={i} citation={citation} index={i} />
                  ))}
                </ul>
              </div>
            )}
          </div>
        )}
      </section>
    </Layout>
  );
}
