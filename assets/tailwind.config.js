module.exports = {
  mode: 'jit',
  purge: ["./js/**/*.js", "./css/**/*.*css", "../lib/*_web/**/*.*ex"],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        gray: {
          950: "#0F131A",
        },
      },
    },
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
