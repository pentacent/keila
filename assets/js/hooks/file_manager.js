const FileManager = {
  mounted() {
    this.handleEvent("remove_file", ({ id }) => {
      document.getElementById(id)?.remove();
    });

    this.handleEvent("file_in_use", ({ campaigns }) => {
      this.el.dispatchEvent(
        new CustomEvent("x-file-in-use", {
          detail: { campaigns },
          bubbles: true,
        })
      );
    });
  },
};

export { FileManager };
