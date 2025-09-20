import React from 'react';
import { motion } from 'framer-motion';
import { Button } from '@/components/ui/button';
import { useToast } from '@/components/ui/use-toast';
import { Star, Gift, Coins, Trophy } from 'lucide-react';

const Incentives = () => {
  const { toast } = useToast();

  const handleJoinProgram = () => {
    toast({
      title: "🚧 This feature isn't implemented yet—but don't worry! You can request it in your next prompt! 🚀"
    });
  };

  const incentivePrograms = [
    {
      icon: Star,
      title: "Creator Rewards",
      description: "Get your high-quality content 'Hyped' by Community Managers to earn SWT tokens.",
      benefits: ["+100 SWT per Hyped Message", "Weekly NTT Token Airdrops", "Build On-chain Reputation"],
      color: "from-yellow-400 to-orange-500"
    },
    {
      icon: Trophy,
      title: "Manager Voting Rewards",
      description: "Manager NFT holders earn rewards for actively curating content through voting.",
      benefits: ["+10 SWT per Vote (Hype/Spam)", "Shape Community Standards", "Tradable Manager NFT"],
      color: "from-blue-400 to-cyan-500"
    },
    {
      icon: Coins,
      title: "SUI<>SWT Liquidity",
      description: "Provide liquidity to the on-chain SUI<>SWT swap pool to earn fees and support the ecosystem.",
      benefits: ["Earn Trading Fees", "Flexible Liquidity Provision", "Strengthen Token Value"],
      color: "from-purple-400 to-pink-500"
    },
    {
      icon: Gift,
      title: "NTT Airdrops",
      description: "Top contributors are rewarded weekly with random airdrops of NTT tokens from Wormhole.",
      benefits: ["Multi-chain Asset Rewards", "Incentive for Quality", "Powered by Wormhole NTT"],
      color: "from-green-400 to-blue-500"
    }
  ];

  return (
    <section className="py-20 px-4 relative">
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-gradient-to-r from-blue-500/10 to-purple-500/10 rounded-full blur-3xl"></div>
      </div>

      <div className="max-w-6xl mx-auto relative z-10">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          viewport={{ once: true }}
          className="text-center mb-16"
        >
          <h2 className="text-4xl md:text-5xl font-bold mb-6 bg-gradient-to-r from-purple-400 to-cyan-400 bg-clip-text text-transparent">
            Powerful Incentives for All
          </h2>
          <p className="text-xl text-blue-200 max-w-3xl mx-auto">
            Whether you're a creator, curator, or liquidity provider, SuiWorld rewards your contributions.
          </p>
        </motion.div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-16">
          {incentivePrograms.map((program, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, x: index % 2 === 0 ? -30 : 30 }}
              whileInView={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.8, delay: index * 0.2 }}
              viewport={{ once: true }}
              className="group"
            >
              <div className="bg-gradient-to-br from-blue-900/40 to-purple-900/40 backdrop-blur-sm border border-blue-500/30 rounded-3xl p-8 h-full transform hover:scale-105 transition-all duration-300 hover:shadow-2xl hover:shadow-purple-500/20">
                <div className={`bg-gradient-to-r ${program.color} w-20 h-20 rounded-3xl flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300`}>
                  <program.icon className="h-10 w-10 text-white" />
                </div>
                
                <h3 className="text-2xl font-bold text-white mb-4 group-hover:text-purple-300 transition-colors duration-300">
                  {program.title}
                </h3>
                
                <p className="text-blue-200 mb-6 leading-relaxed">
                  {program.description}
                </p>

                <div className="space-y-3">
                  {program.benefits.map((benefit, benefitIndex) => (
                    <div key={benefitIndex} className="flex items-center space-x-3">
                      <div className="w-2 h-2 bg-gradient-to-r from-blue-400 to-purple-400 rounded-full"></div>
                      <span className="text-blue-100">{benefit}</span>
                    </div>
                  ))}
                </div>
              </div>
            </motion.div>
          ))}
        </div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          viewport={{ once: true }}
          className="text-center bg-gradient-to-r from-blue-900/50 to-purple-900/50 backdrop-blur-sm border border-blue-500/30 rounded-3xl p-12"
        >
          <h3 className="text-3xl font-bold text-white mb-4">
            Ready to Start Earning?
          </h3>
          <p className="text-xl text-blue-200 mb-8 max-w-2xl mx-auto">
            Join our ecosystem and get rewarded for your valuable contributions to the world of decentralized intelligence.
          </p>
          <Button
            onClick={handleJoinProgram}
            size="lg"
            className="bg-gradient-to-r from-purple-500 to-cyan-600 hover:from-purple-600 hover:to-cyan-700 text-white px-12 py-4 text-lg font-semibold rounded-full shadow-2xl transform hover:scale-105 transition-all duration-300"
          >
            Join the Ecosystem
          </Button>
        </motion.div>
      </div>
    </section>
  );
};

export default Incentives;