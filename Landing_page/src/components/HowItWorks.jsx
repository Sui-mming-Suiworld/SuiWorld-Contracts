import React from 'react';
import { motion } from 'framer-motion';
import { PenSquare, CheckCircle, Award, ShieldAlert } from 'lucide-react';

const HowItWorks = () => {
  const steps = [
    {
      icon: PenSquare,
      title: "1. Create Content",
      description: "Users holding ≥1000 SWT can write and share high-quality intelligence (Intels) on the platform's feed.",
      color: "text-blue-400"
    },
    {
      icon: CheckCircle,
      title: "2. Community Review",
      description: "Messages with 20+ likes enter 'Under Review'. 12 Community Managers vote to determine if it's 'Hyped' or 'Spam'.",
      color: "text-purple-400"
    },
    {
      icon: Award,
      title: "3. Earn Rewards (Hyped)",
      description: "If a message is voted 'Hyped', the creator earns +100 SWT and voting managers earn +10 SWT each.",
      color: "text-green-400"
    },
    {
      icon: ShieldAlert,
      title: "4. Face Penalties (Spam)",
      description: "If a message is voted 'Spam', the creator is penalized -200 SWT, while voting managers still earn +10 SWT.",
      color: "text-red-400"
    }
  ];

  return (
    <section className="py-20 px-4 bg-blue-900/20">
      <div className="max-w-6xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          viewport={{ once: true }}
          className="text-center mb-16"
        >
          <h2 className="text-4xl md:text-5xl font-bold mb-6 bg-gradient-to-r from-cyan-400 to-purple-400 bg-clip-text text-transparent">
            How the Incentive Model Works
          </h2>
          <p className="text-xl text-blue-200 max-w-3xl mx-auto">
            Our tokenomics create a self-sustaining ecosystem that rewards quality and penalizes spam.
          </p>
        </motion.div>

        <div className="relative">
          <div className="hidden md:block absolute top-1/2 left-0 w-full h-0.5 bg-blue-500/30 transform -translate-y-1/2"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            {steps.map((step, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 50 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: index * 0.2 }}
                viewport={{ once: true }}
                className="text-center p-6 bg-blue-900/40 border border-blue-500/20 rounded-2xl relative"
              >
                <div className="flex justify-center mb-4">
                  <div className="w-16 h-16 rounded-full bg-blue-900 flex items-center justify-center border-2 border-blue-500/50">
                    <step.icon className={`h-8 w-8 ${step.color}`} />
                  </div>
                </div>
                <h3 className="text-xl font-bold text-white mb-2">{step.title}</h3>
                <p className="text-blue-200">{step.description}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
};

export default HowItWorks;