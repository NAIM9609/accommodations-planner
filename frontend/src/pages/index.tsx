import Head from 'next/head';
import Link from 'next/link';
import Layout from '../components/Layout';

function HomePage(): JSX.Element {
  return (
    <Layout>
      <Head>
        <title>Maple Grove B&B - Your Home Away From Home</title>
        <meta name="description" content="Welcome to Maple Grove Bed & Breakfast" />
      </Head>

      {/* Hero — mobile-first via .hero, .hero__title, .hero__subtitle, .hero__cta */}
      <section className="hero">
        <h1 className="hero__title">
          🏡 Maple Grove B&B
        </h1>
        <p className="hero__subtitle">
          Experience the warmth and comfort of our charming bed &amp; breakfast nestled in the heart of nature.
        </p>
        <Link href="/reservations" className="hero__cta">
          Book Your Stay →
        </Link>
      </section>

      {/* Features — .feature-grid: 1 col → 2 col → 4 col */}
      <section className="section-inner">
        <h2 className="section-title">Why Choose Us?</h2>
        <div className="feature-grid">
          {[
            { icon: '🛏️', title: 'Cozy Rooms', desc: 'Hand-crafted furnishings, plush bedding, and stunning views to make every night restful.' },
            { icon: '🍳', title: 'Homemade Breakfast', desc: 'Start your day with a freshly prepared breakfast featuring local seasonal ingredients.' },
            { icon: '🌲', title: 'Nature Surroundings', desc: 'Peaceful trails, fresh air, and wildlife right at your doorstep.' },
            { icon: '📍', title: 'Prime Location', desc: 'Minutes from local attractions, restaurants, and historic landmarks.' },
          ].map(f => (
            <div key={f.title} style={{
              background: 'white',
              borderRadius: '12px',
              padding: '24px',
              boxShadow: '0 4px 20px rgba(0,0,0,0.08)',
              textAlign: 'center',
            }}>
              <div style={{ fontSize: '2.5rem', marginBottom: '16px' }}>{f.icon}</div>
              <h3 style={{ marginBottom: '12px', color: '#444', fontSize: '1.2rem' }}>{f.title}</h3>
              <p style={{ color: '#666', lineHeight: 1.6, margin: 0 }}>{f.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Rooms — .room-grid: 1 col → 2 col → 3 col */}
      <section style={{ background: '#f0f2f5', padding: '0' }}>
        <div className="section-inner">
          <h2 className="section-title">Our Rooms</h2>
          <div className="room-grid">
            {[
              { name: 'Standard Room', price: '$89/night', desc: 'Comfortable and cozy, perfect for solo travelers or couples.', emoji: '🛏️' },
              { name: 'Deluxe Room', price: '$129/night', desc: 'Spacious room with garden view and premium amenities.', emoji: '🌸' },
              { name: 'Suite', price: '$189/night', desc: 'Our finest accommodation with panoramic views and a private sitting area.', emoji: '👑' },
            ].map(room => (
              <div key={room.name} style={{
                background: 'white',
                borderRadius: '12px',
                overflow: 'hidden',
                boxShadow: '0 4px 20px rgba(0,0,0,0.08)',
              }}>
                <div style={{
                  background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                  height: '140px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '3.5rem',
                }}>
                  {room.emoji}
                </div>
                <div style={{ padding: '20px' }}>
                  <h3 style={{ margin: '0 0 8px', color: '#333' }}>{room.name}</h3>
                  <p style={{ color: '#764ba2', fontWeight: 700, margin: '0 0 12px' }}>{room.price}</p>
                  <p style={{ color: '#666', lineHeight: 1.6, margin: '0 0 20px' }}>{room.desc}</p>
                  <Link href="/reservations" style={{
                    display: 'inline-block',
                    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                    color: 'white',
                    padding: '10px 24px',
                    borderRadius: '6px',
                    textDecoration: 'none',
                    fontWeight: 600,
                    minHeight: '44px',
                    lineHeight: '24px',
                  }}>
                    Reserve Now
                  </Link>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section style={{ padding: '48px 16px', textAlign: 'center' }}>
        <h2 style={{ fontSize: 'clamp(1.4rem, 4vw, 2rem)', marginBottom: '16px', color: '#333' }}>Ready to Book?</h2>
        <p style={{ color: '#666', marginBottom: '28px', fontSize: 'clamp(1rem, 2vw, 1.1rem)' }}>
          Check availability and make your reservation today.
        </p>
        <Link href="/reservations" style={{
          display: 'inline-block',
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          color: 'white',
          padding: '14px 32px',
          borderRadius: '30px',
          textDecoration: 'none',
          fontWeight: 700,
          fontSize: 'clamp(0.95rem, 2vw, 1.1rem)',
          minHeight: '48px',
          lineHeight: '1.4',
        }}>
          View &amp; Make Reservations
        </Link>
      </section>
    </Layout>
  );
}

export default HomePage;

