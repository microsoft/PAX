/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{ts,tsx,js,jsx}'
  ],
  theme: {
    extend: {
      borderRadius: {
        DEFAULT: '0.5rem'
      }
    }
  },
  plugins: []
};


