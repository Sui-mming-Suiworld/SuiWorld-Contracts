// frontend/tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: { blue: "#4DA3FF" },
        card: "#1F1F1F",
      },
    },
  },
  plugins: [],
};