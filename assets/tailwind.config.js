module.exports = {
  purge: [
    '../lib/**/*.ex',
    '../lib/**/*.leex',
    '../lib/**/*.eex',
    './js/**/*.js'
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {},
  },
  variants: {
    extend: {
      backgroundColor: ['active'],
      ringColor: ['responsive', 'dark', 'focus-within', 'focus', 'hover'],
      ringOffsetColor: ['responsive', 'dark', 'focus-within', 'focus', 'hover'],
      ringOffsetWidth: ['responsive', 'focus-within', 'focus', 'hover'],
      ringOpacity: ['responsive', 'focus-within', 'focus', 'hover'],
      ringWidth: ['responsive', 'focus-within', 'focus', 'hover'],
      
    },
  },
  plugins: [require('@tailwindcss/forms')],
}
