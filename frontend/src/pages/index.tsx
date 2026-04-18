import Head from 'next/head';
import Link from 'next/link';
import { useTranslation } from 'react-i18next';
import Layout from '../components/Layout';
import { BRAND } from '../lib/brand';

function HomePage(): JSX.Element {
  const { t } = useTranslation();

  const suites = [
    {
      key: 'gardenTerrace',
      tone: 'room-card room-card--sand',
    },
    {
      key: 'seaHorizon',
      tone: 'room-card room-card--slate',
    },
    {
      key: 'grandVilla',
      tone: 'room-card room-card--olive',
    },
  ];

  const experiences = [
    { key: 'sunsetCruise' },
    { key: 'vineyardJourney' },
    { key: 'heritageWalk' },
  ];

  return (
    <Layout>
      <Head>
        <title>{BRAND.fullName}</title>
        <meta
          name="description"
          content={t('home.metaDescription')}
        />
      </Head>

      <section className="lux-hero" aria-labelledby="lux-hero-title">
        <div className="lux-hero__veil" />
        <div className="lux-hero__content">
          <p className="lux-kicker">{BRAND.fullName}</p>
          <h1 id="lux-hero-title" className="lux-hero__title">
            {t('home.heroTitle')}
          </h1>
          <p className="lux-hero__subtitle">
            {t('home.heroSubtitle', { brandName: BRAND.shortName })}
          </p>
          <div className="lux-hero__actions">
            <Link href="/reservations" className="lux-btn lux-btn--solid">
              {t('home.checkRates')}
            </Link>
            <a href="#discover" className="lux-btn lux-btn--ghost">
              {t('home.exploreRetreat')}
            </a>
          </div>
        </div>
        <div className="booking-strip" role="region" aria-label="Quick booking">
          <div className="booking-strip__field">
            <span className="booking-strip__label">{t('home.arrival')}</span>
            <span className="booking-strip__value">{t('home.flexibleDates')}</span>
          </div>
          <div className="booking-strip__field">
            <span className="booking-strip__label">{t('home.departure')}</span>
            <span className="booking-strip__value">{t('home.flexibleDates')}</span>
          </div>
          <div className="booking-strip__field">
            <span className="booking-strip__label">{t('home.guests')}</span>
            <span className="booking-strip__value">{t('home.twoAdults')}</span>
          </div>
          <Link href="/reservations" className="booking-strip__cta">
            {t('home.reserveNow')}
          </Link>
        </div>
      </section>

      <section className="lux-intro section-inner" id="discover" aria-labelledby="discover-title">
        <div className="lux-intro__copy">
          <p className="lux-kicker">{t('home.unparalleledStay')}</p>
          <h2 id="discover-title" className="lux-heading">
            {t('home.introHeading')}
          </h2>
          <p>
            {t('home.introDesc')}
          </p>
          <Link href="/reservations" className="lux-text-link">
            {t('home.planItinerary')}
          </Link>
        </div>
        <div className="lux-intro__visual" aria-hidden="true" />
      </section>

      <section className="lux-section lux-section--stone" aria-labelledby="accommodations-title">
        <div className="section-inner">
          <p className="lux-kicker">{t('home.accommodations')}</p>
          <h2 id="accommodations-title" className="lux-heading">{t('home.suitesHeading')}</h2>
          <div className="lux-grid lux-grid--three">
            {suites.map((suite) => (
              <article key={suite.key} className={suite.tone}>
                <div className="room-card__media" aria-hidden="true" />
                <div className="room-card__body">
                  <h3>{t(`home.suites.${suite.key}.name`)}</h3>
                  <p className="room-card__rate">{t(`home.suites.${suite.key}.rate`)}</p>
                  <p>{t(`home.suites.${suite.key}.desc`)}</p>
                  <Link href="/reservations" className="lux-text-link">
                    {t('home.viewRoomDetails')}
                  </Link>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="lux-section" aria-labelledby="experiences-title">
        <div className="section-inner">
          <p className="lux-kicker">{t('home.discoverBrand', { brandName: BRAND.shortName })}</p>
          <h2 id="experiences-title" className="lux-heading">{t('home.experiencesHeading')}</h2>
          <div className="lux-grid lux-grid--three">
            {experiences.map((item) => (
              <article key={item.key} className="experience-card">
                <p className="experience-card__detail">{t(`home.experiences.${item.key}.detail`)}</p>
                <h3>{t(`home.experiences.${item.key}.title`)}</h3>
                <p>{t(`home.experiences.${item.key}.blurb`)}</p>
                <Link href="/reservations" className="lux-text-link">
                  {t('home.speakConcierge')}
                </Link>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="lux-offers section-inner" aria-labelledby="offers-title">
        <p className="lux-kicker">{t('home.featuredOffers')}</p>
        <h2 id="offers-title" className="lux-heading">{t('home.offersHeading')}</h2>
        <div className="lux-grid lux-grid--two">
          <article className="offer-card">
            <h3>{t('home.offerCreditTitle')}</h3>
            <p>{t('home.offerCreditDesc')}</p>
            <Link href="/reservations" className="lux-text-link">{t('home.viewOfferTerms')}</Link>
          </article>
          <article className="offer-card">
            <h3>{t('home.offerEscapeTitle')}</h3>
            <p>{t('home.offerEscapeDesc')}</p>
            <Link href="/reservations" className="lux-text-link">{t('home.seeAvailability')}</Link>
          </article>
        </div>
      </section>

      <section className="lux-spa" aria-labelledby="spa-title">
        <div className="lux-spa__inner section-inner">
          <div>
            <p className="lux-kicker">{t('home.wellnessSanctuary')}</p>
            <h2 id="spa-title" className="lux-heading">{t('home.spaHeading')}</h2>
            <p>
              {t('home.spaDesc')}
            </p>
          </div>
          <Link href="/reservations" className="lux-btn lux-btn--solid">
            {t('home.reserveYourStay')}
          </Link>
        </div>
      </section>
    </Layout>
  );
}

export default HomePage;
