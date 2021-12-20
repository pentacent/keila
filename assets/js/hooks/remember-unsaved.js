export function RememberUnsaved() {
  return {
    changed: false,
    init() {
      window.addEventListener("beforeunload", (e) => {
        if (this.changed) {
          e.preventDefault();
          e.returnValue = "Unsaved changes will be lost. Are you sure?";
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
