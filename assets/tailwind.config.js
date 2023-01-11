module.exports = {
  content: ["./js/**/*.js", "./css/**/*.*css", "../lib/*_web/**/*.*ex"],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        gray: {
          950: "#0F131A"
        }
      }
    }
  },
  plugins: [require("@tailwindcss/forms")]
}
