let unsaved = false
export const RememberUnsaved = {
    mounted() {
      window.setUnsavedReminder = (enable) => {
        unsaved = enable
      }
      window.addEventListener("beforeunload", (e) => {
        if (unsaved) {
          e.preventDefault();
          e.returnValue = '';
        }
      })
    },
}
