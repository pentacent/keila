export function RememberUnsaved() {
  return {
    changed: false,
    init(msg) {
      window.addEventListener("beforeunload", (e) => {
        if (this.changed) {
          e.preventDefault();
          e.returnValue = msg;
        }
      })
    },
    trigger() {
      this.changed = true;
    },
    reset() {
      this.changed = false;
    }
  }
}
