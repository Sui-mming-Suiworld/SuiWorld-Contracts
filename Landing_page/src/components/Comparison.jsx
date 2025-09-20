import React from 'react';
import { motion } from 'framer-motion';
import { XCircle, CheckCircle, Archive, BarChart3, Link2Off, Award, Users, Zap } from 'lucide-react';

const Comparison = () => {
  const problems = [
    {
      icon: Archive,
      title: "Grave of Information",
      description: "Randomly spread, low-quality information on social media increases user stress when seeking valuable intel."
    },
    {
      icon: Link2Off,
      title: "Disconnected from the Ecosystem",
      description: "Contributions are detached from on-chain activity, preventing them from fostering ecosystem growth and long-term community."
    },
    {
      icon: BarChart3,
      title: "Inefficient Marketing",
      description: "Influencer-centric promotion leads to low conversion rates and fails to build sustainable trust."
    }
  ];

  const solutions = [
    {
      icon: Award,
      title: "Quality-Driven Curation",
      description: "An incentive model and community managers ensure that high-quality information is surfaced and rewarded."
    },
    {
      icon: Zap,
      title: "Integrated with the Ecosystem",
      description: "All activities are on-chain transactions, directly contributing to the Sui network's growth and building user reputation."
    },
    {
      icon: Users,
      title: "Sustainable Community Trust",
      description: "Trust is built organically through a transparent, fair system, not through costly, short-term influencer campaigns."
    }
  ];

  return (
    <section className="py-20 px-4 bg-black/20">
      <div className="max-w-7xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          viewport={{ once: true }}
          className="text-center mb-16"
        >
          <h2 className="text-4xl md:text-5xl font-bold mb-6 bg-gradient-to-r from-red-500 via-yellow-400 to-green-400 bg-clip-text text-transparent">
            Solving the Problems of InfoFi
          </h2>
          <p className="text-xl text-blue-200 max-w-3xl mx-auto">
            SuiWorld was built to overcome the limitations of existing information platforms.
          </p>
        </motion.div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Problems Column */}
          <motion.div
            initial={{ opacity: 0, x: -50 }}
            whileInView={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.2 }}
            viewport={{ once: true }}
            className="bg-gradient-to-br from-gray-900/50 to-red-900/20 border border-red-500/30 rounded-2xl p-8"
          >
            <div className="flex items-center mb-6">
              <XCircle className="h-10 w-10 text-red-500 mr-4" />
              <h3 className="text-3xl font-bold text-white">The Old Way: InfoFi Problems</h3>
            </div>
            <div className="space-y-6">
              {problems.map((item, index) => (
                <div key={index} className="flex items-start">
                  <div className="bg-red-500/20 p-3 rounded-lg mr-4">
                    <item.icon className="h-6 w-6 text-red-400" />
                  </div>
                  <div>
                    <h4 className="font-semibold text-lg text-red-200">{item.title}</h4>
                    <p className="text-gray-400">{item.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </motion.div>

          {/* Solutions Column */}
          <motion.div
            initial={{ opacity: 0, x: 50 }}
            whileInView={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.4 }}
            viewport={{ once: true }}
            className="bg-gradient-to-br from-gray-900/50 to-green-900/20 border border-green-500/30 rounded-2xl p-8"
          >
            <div className="flex items-center mb-6">
              <CheckCircle className="h-10 w-10 text-green-500 mr-4" />
              <h3 className="text-3xl font-bold text-white">The SuiWorld Way: Our Solution</h3>
            </div>
            <div className="space-y-6">
              {solutions.map((item, index) => (
                <div key={index} className="flex items-start">
                  <div className="bg-green-500/20 p-3 rounded-lg mr-4">
                    <item.icon className="h-6 w-6 text-green-400" />
                  </div>
                  <div>
                    <h4 className="font-semibold text-lg text-green-200">{item.title}</h4>
                    <p className="text-gray-300">{item.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
};

export default Comparison;