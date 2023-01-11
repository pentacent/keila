const CampaignSettingsDialogHook = {
  mounted() {
    this.handleEvent("settings_validated", ({ valid }) => {
      if (valid) {
        this.el.dispatchEvent(new CustomEvent("x-confirm", { detail: {} }))
      }
    })
  }
}

export { CampaignSettingsDialogHook }
