import Head from 'next/head';
import Link from 'next/link';
import Layout from '../components/Layout';
import { BRAND } from '../lib/brand';

function HomePage(): JSX.Element {
  const suites = [
    {
      name: 'Garden Terrace Room',
      rate: 'From $289 / night',
      desc: 'A quiet retreat with private terrace seating, handcrafted linens, and morning light over the orchard.',
      tone: 'room-card room-card--sand',
    },
    {
      name: 'Sea Horizon Suite',
      rate: 'From $429 / night',
      desc: 'Expansive indoor-outdoor living with panoramic bay views, marble bath, and curated welcome amenities.',
      tone: 'room-card room-card--slate',
    },
    {
      name: 'Grand Villa Residence',
      rate: 'From $690 / night',
      desc: 'A private residence experience with dedicated host service, sunset lounge deck, and chef breakfast.',
      tone: 'room-card room-card--olive',
    },
  ];

  const experiences = [
    {
      title: 'Sunset Coastal Cruise',
      detail: '3 hours',
      blurb: 'Sail the cliffline at golden hour with a sommelier-led tasting of local sparkling wines.',
    },
    {
      title: 'Volcanic Vineyard Journey',
      detail: 'Half day',
      blurb: 'Travel into the highlands for cellar tours, chef-paired lunch, and views over ancient terraces.',
    },
    {
      title: 'Cinema & Heritage Walk',
      detail: '4 hours',
      blurb: 'Discover storied piazzas and iconic filming landmarks with a private cultural concierge.',
    },
  ];

  return (
    <Layout>
      <Head>
        <title>{BRAND.fullName}</title>
        <meta
          name="description"
          content="A refined coastal retreat with curated suites, signature experiences, and elevated dining."
        />
      </Head>

      <section className="lux-hero" aria-labelledby="lux-hero-title">
        <div className="lux-hero__veil" />
        <div className="lux-hero__content">
          <p className="lux-kicker">{BRAND.fullName}</p>
          <h1 id="lux-hero-title" className="lux-hero__title">
            Cliffside serenity with timeless Mediterranean soul
          </h1>
          <p className="lux-hero__subtitle">
            Set high above the waterline, {BRAND.shortName} blends heritage architecture, botanical gardens, and modern
            hospitality into one immersive stay.
          </p>
          <div className="lux-hero__actions">
            <Link href="/reservations" className="lux-btn lux-btn--solid">
              Check rates
            </Link>
            <a href="#discover" className="lux-btn lux-btn--ghost">
              Explore the retreat
            </a>
          </div>
        </div>
        <div className="booking-strip" role="region" aria-label="Quick booking">
          <div className="booking-strip__field">
            <span className="booking-strip__label">Arrival</span>
            <span className="booking-strip__value">Flexible dates</span>
          </div>
          <div className="booking-strip__field">
            <span className="booking-strip__label">Departure</span>
            <span className="booking-strip__value">Flexible dates</span>
          </div>
          <div className="booking-strip__field">
            <span className="booking-strip__label">Guests</span>
            <span className="booking-strip__value">2 adults</span>
          </div>
          <Link href="/reservations" className="booking-strip__cta">
            Reserve now
          </Link>
        </div>
      </section>

      <section className="lux-intro section-inner" id="discover" aria-labelledby="discover-title">
        <div className="lux-intro__copy">
          <p className="lux-kicker">Unparalleled Stay</p>
          <h2 id="discover-title" className="lux-heading">
            A five-star hideaway designed for slow mornings and cinematic evenings
          </h2>
          <p>
            Originally conceived as a hillside estate and now reimagined as a contemporary sanctuary, our retreat offers
            sea-facing terraces, fragrant citrus courtyards, and personalized service that anticipates every detail.
          </p>
          <Link href="/reservations" className="lux-text-link">
            Plan your itinerary
          </Link>
        </div>
        <div className="lux-intro__visual" aria-hidden="true" />
      </section>

      <section className="lux-section lux-section--stone" aria-labelledby="accommodations-title">
        <div className="section-inner">
          <p className="lux-kicker">Accommodations</p>
          <h2 id="accommodations-title" className="lux-heading">Suites crafted for quiet luxury</h2>
          <div className="lux-grid lux-grid--three">
            {suites.map((suite) => (
              <article key={suite.name} className={suite.tone}>
                <div className="room-card__media" aria-hidden="true" />
                <div className="room-card__body">
                  <h3>{suite.name}</h3>
                  <p className="room-card__rate">{suite.rate}</p>
                  <p>{suite.desc}</p>
                  <Link href="/reservations" className="lux-text-link">
                    View room details
                  </Link>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="lux-section" aria-labelledby="experiences-title">
        <div className="section-inner">
          <p className="lux-kicker">Discover {BRAND.shortName}</p>
          <h2 id="experiences-title" className="lux-heading">Curated experiences beyond the retreat</h2>
          <div className="lux-grid lux-grid--three">
            {experiences.map((item) => (
              <article key={item.title} className="experience-card">
                <p className="experience-card__detail">{item.detail}</p>
                <h3>{item.title}</h3>
                <p>{item.blurb}</p>
                <Link href="/reservations" className="lux-text-link">
                  Speak with concierge
                </Link>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="lux-offers section-inner" aria-labelledby="offers-title">
        <p className="lux-kicker">Featured Offers</p>
        <h2 id="offers-title" className="lux-heading">Seasonal privileges for longer stays</h2>
        <div className="lux-grid lux-grid--two">
          <article className="offer-card">
            <h3>Experience More Credit</h3>
            <p>Receive a $220 resort credit to elevate your stay with wellness sessions, dining, or private excursions.</p>
            <Link href="/reservations" className="lux-text-link">View offer terms</Link>
          </article>
          <article className="offer-card">
            <h3>Suite Escape - 15% Off</h3>
            <p>Stay three nights or more and enjoy preferred rates, daily breakfast, and expedited coastal transfers.</p>
            <Link href="/reservations" className="lux-text-link">See availability</Link>
          </article>
        </div>
      </section>

      <section className="lux-spa" aria-labelledby="spa-title">
        <div className="lux-spa__inner section-inner">
          <div>
            <p className="lux-kicker">Wellness Sanctuary</p>
            <h2 id="spa-title" className="lux-heading">Restore at our botanical spa</h2>
            <p>
              Signature rituals draw on citrus oils, marine minerals, and thermal therapies to restore body and mind.
            </p>
          </div>
          <Link href="/reservations" className="lux-btn lux-btn--solid">
            Reserve your stay
          </Link>
        </div>
      </section>
    </Layout>
  );
}

export default HomePage;

