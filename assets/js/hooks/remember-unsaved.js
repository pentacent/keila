const RememberUnsaved = {
  mounted() {
    this.beforeUnload = (e) => {
      if (this.data.changed) {
        e.preventDefault();
        e.returnValue = "Unsaved changes will be lost. Are you sure?";
      }
    }
    window.addEventListener("beforeunload", this.beforeUnload);
  },
  destroyed() {
    window.removeEventListener("beforeunload", this.beforeUnload);
  }
};

export { RememberUnsaved }