import React from 'react';
import { Helmet } from 'react-helmet';
import { motion } from 'framer-motion';
import { Toaster } from '@/components/ui/toaster';
import Hero from '@/components/Hero';
import Comparison from '@/components/Comparison';
import Features from '@/components/Features';
import Incentives from '@/components/Incentives';
import CTA from '@/components/CTA';
import Footer from '@/components/Footer';
import HowItWorks from '@/components/HowItWorks';

function App() {
  return (
    <>
      <Helmet>
        <title>SuiWorld - SocialFi Platform with a Powerful Incentive Model for High-Quality Intels</title>
        <meta name="description" content="Join SuiWorld, the SocialFi platform on the Sui blockchain that creates a virtuous cycle of production, verification, and compensation for high-quality intelligence." />
      </Helmet>
      
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-black to-slate-900 text-white overflow-hidden">
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.8 }}
        >
          <Hero />
          <Comparison />
          <Features />
          <HowItWorks />
          <Incentives />
          <CTA />
          <Footer />
        </motion.div>
        <Toaster />
      </div>
    </>
  );
}

export default App;