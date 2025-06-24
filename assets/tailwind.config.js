module.exports = {
  darkMode: false, // or 'media' or 'class'
  content: ["./js/**/*.js", "./css/**/*.*css", "../lib/*_web/**/*.*ex", "../extra/**/*_web/**/*.*ex"],
  theme: {
    extend: {
      colors: {
        gray: {
          950: "#0F131A"
        }
      }
    }
  },
  plugins: [require("@tailwindcss/forms"), require("@tailwindcss/typography")]
}
