// frontend/tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: { blue: "#4DA3FF" },
        card: "#f3f4f6",
      },
    },
  },
  plugins: [],
};
