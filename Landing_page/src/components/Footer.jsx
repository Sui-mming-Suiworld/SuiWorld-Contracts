import React from 'react';
import { motion } from 'framer-motion';
import { useToast } from '@/components/ui/use-toast';
import { Twitter, Github, Linkedin, Mail } from 'lucide-react';

const Footer = () => {
  const { toast } = useToast();

  const handleSocialClick = (platform) => {
    toast({
      title: "🚧 This feature isn't implemented yet—but don't worry! You can request it in your next prompt! 🚀"
    });
  };

  const handleLinkClick = () => {
    toast({
      title: "🚧 This feature isn't implemented yet—but don't worry! You can request it in your next prompt! 🚀"
    });
  };

  return (
    <footer className="py-16 px-4 border-t border-blue-500/20 bg-gradient-to-br from-blue-900/30 to-purple-900/30 backdrop-blur-sm">
      <div className="max-w-6xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          viewport={{ once: true }}
          className="grid grid-cols-1 md:grid-cols-4 gap-8 mb-12"
        >
          <div className="md:col-span-2">
            <div className="flex items-center space-x-3 mb-4">
              <img 
                src="https://horizons-cdn.hostinger.com/af3bee6b-1bbc-4a7a-9180-dd14b1bb29a5/3227bdb231a5cee9e678137041334ec2.png"
                alt="SuiWorld logo"
                className="w-10 h-10"
              />
              <span className="text-2xl font-bold bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">
                SuiWorld
              </span>
            </div>
            <p className="text-blue-200 mb-6 max-w-md leading-relaxed">
              A SocialFi platform on Sui creating a virtuous cycle for the production, verification, and compensation of high-quality intelligence.
            </p>
            
            <div className="flex space-x-4">
              {[
                { icon: Twitter, label: 'Twitter', type: 'button', href: 'https://x.com/SWT_SuiWorld'},
                { icon: Github, label: 'GitHub', type: 'link', href: 'https://github.com/Sui-mming-Suiworld' },
                { icon: Linkedin, label: 'LinkedIn', type: 'button' },
                { icon: Mail, label: 'Email', type: 'button' }
              ].map((social, index) => (
                social.type === 'button' ? (
                  <button
                    key={index}
                    onClick={() => handleSocialClick(social.label)}
                    className="bg-blue-900/50 hover:bg-blue-800/50 p-3 rounded-full transition-all duration-300 hover:scale-110 border border-blue-500/30"
                    aria-label={social.label}
                  >
                    <social.icon className="h-5 w-5 text-blue-300" />
                  </button>
                ) : (
                  <a
                    key={index}
                    href={social.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="bg-blue-900/50 hover:bg-blue-800/50 p-3 rounded-full transition-all duration-300 hover:scale-110 border border-blue-500/30 flex items-center justify-center"
                    aria-label={social.label}
                  >
                    <social.icon className="h-5 w-5 text-blue-300" />
                  </a>
                )
              ))}
            </div>
          </div>

          <div>
            <span className="text-lg font-semibold text-white mb-4 block">Platform</span>
            <nav className="space-y-3">
              {['Features', 'Tokenomics', 'Managers', 'Roadmap'].map((link) => (
                <button
                  key={link}
                  onClick={handleLinkClick}
                  className="block text-blue-200 hover:text-blue-300 transition-colors duration-300"
                >
                  {link}
                </button>
              ))}
            </nav>
          </div>

          <div>
            <span className="text-lg font-semibold text-white mb-4 block">Resources</span>
            <nav className="space-y-3">
              {['Documentation', 'Community', 'GitHub', 'Contact Us'].map((link) => (
                <button
                  key={link}
                  onClick={handleLinkClick}
                  className="block text-blue-200 hover:text-blue-300 transition-colors duration-300"
                >
                  {link}
                </button>
              ))}
            </nav>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          viewport={{ once: true }}
          className="pt-8 border-t border-blue-500/20 flex flex-col md:flex-row justify-between items-center space-y-4 md:space-y-0"
        >
          <p className="text-blue-300 text-sm">
            © 2025 SuiWorld. All rights reserved.
          </p>
          
          <div className="flex space-x-6 text-sm">
            {['Privacy Policy', 'Terms of Service', 'Cookie Policy'].map((link) => (
              <button
                key={link}
                onClick={handleLinkClick}
                className="text-blue-300 hover:text-blue-200 transition-colors duration-300"
              >
                {link}
              </button>
            ))}
          </div>
        </motion.div>
      </div>
    </footer>
  );
};

export default Footer;