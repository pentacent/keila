const FileManager = {
  mounted() {
    this.handleEvent("remove_file", ({ id }) => {
      document.getElementById(id)?.remove();
    });
  },
};

export { FileManager };
