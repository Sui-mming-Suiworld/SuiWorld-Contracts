import React from 'react';
import { motion } from 'framer-motion';
import { Users, Zap, Shield, TrendingUp, Globe, KeyRound } from 'lucide-react';
const Features = () => {
  const features = [{
    icon: KeyRound,
    title: "Onboarding with zkLogin",
    description: "Start in one click with seedless wallet onboarding. Your wallet and profile are linked for seamless social functions."
  }, {
    icon: Zap,
    title: "SWT Tokenomics",
    description: "Our native SWT token powers the ecosystem, granting rights to write and interact, with a SUI<>SWT swap pool for liquidity."
  }, {
    icon: Users,
    title: "Powerful Community Managers",
    description: "12 Manager NFT holders curate content, voting to hype or remove messages, ensuring community quality and neutrality."
  }, {
    icon: TrendingUp,
    title: "Incentivized Participation",
    description: "Earn SWT rewards for creating high-quality content and participating in content verification votes as a manager."
  }, {
    icon: Globe,
    title: "Wormhole NTT Integration",
    description: "Bridge assets from other chains like ETH and SOL, and receive weekly airdrop rewards in NTT tokens for top contributions."
  }, {
    icon: Shield,
    title: "Manager Resolve System",
    description: "A BFT voting model allows managers to verify and penalize malicious behavior, ensuring long-term platform integrity."
  }];
  return <section className="py-20 px-4 relative">
      <div className="max-w-6xl mx-auto">
        <motion.div initial={{
        opacity: 0,
        y: 30
      }} whileInView={{
        opacity: 1,
        y: 0
      }} transition={{
        duration: 0.8
      }} viewport={{
        once: true
      }} className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold mb-6 bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">Core Features of SuiWorld</h2>
          <p className="text-xl text-blue-200 max-w-3xl mx-auto">
            Discover the innovations that solve the core problems of InfoFi and build a sustainable knowledge ecosystem.
          </p>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, index) => <motion.div key={index} initial={{
          opacity: 0,
          y: 30
        }} whileInView={{
          opacity: 1,
          y: 0
        }} transition={{
          duration: 0.6,
          delay: index * 0.1
        }} viewport={{
          once: true
        }} className="group">
              <div className="bg-gradient-to-br from-blue-900/50 to-purple-900/50 backdrop-blur-sm border border-blue-500/20 rounded-2xl p-8 h-full transform hover:scale-105 transition-all duration-300 hover:shadow-2xl hover:shadow-blue-500/20">
                <div className="bg-gradient-to-r from-blue-500 to-purple-600 w-16 h-16 rounded-2xl flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
                  <feature.icon className="h-8 w-8 text-white" />
                </div>
                
                <h3 className="text-xl font-bold text-white mb-4 group-hover:text-blue-300 transition-colors duration-300">
                  {feature.title}
                </h3>
                
                <p className="text-blue-200 leading-relaxed">
                  {feature.description}
                </p>
              </div>
            </motion.div>)}
        </div>
      </div>
    </section>;
};
export default Features;