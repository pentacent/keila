export function RememberUnsaved() {
  return {
    unsaved: false,
    init(msg) {
      window.addEventListener("beforeunload", (e) => {
        if (this.unsaved) {
          e.preventDefault();
          e.returnValue = msg;
        }
      })
    },
    setUnsavedReminder(val) {
      this.unsaved = val;
    },
  }
}
