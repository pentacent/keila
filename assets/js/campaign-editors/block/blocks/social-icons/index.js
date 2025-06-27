const defaultIconSize = 24
const defaultAlignment = "center"
const defaultBgColor = "#059669"
const knownSites = {
  bluesky: { label: "Bluesky", color: "#00A8E8" },
  discord: { label: "Discord", color: "#5865F2" },
  discourse: { label: "Discourse", color: "#FD8035" },
  facebook: { label: "Facebook", color: "#1877F2" },
  github: { label: "GitHub", color: "#181717" },
  instagram: { label: "Instagram", color: "#E4405F" },
  linkedin: { label: "LinkedIn", color: "#0A66C2" },
  mastodon: { label: "Mastodon", color: "#6364FF" },
  reddit: { label: "Reddit", color: "#FF4500" },
  signal: { label: "Signal", color: "#3A76F0" },
  slack: { label: "Slack", color: "#4A154B" },
  snapchat: { label: "Snapchat", color: "#FFFC00" },
  soundcloud: { label: "SoundCloud", color: "#FF5500" },
  threads: { label: "Threads", color: "#000000" },
  tiktok: { label: "TikTok", color: "#000000" },
  twitch: { label: "Twitch", color: "#9146FF" },
  whatsapp: { label: "WhatsApp", color: "#25D366" },
  "x-twitter": { label: "X (Twitter)", color: "#000000" },
  xing: { label: "Xing", color: "#006567" },
  youtube: { label: "YouTube", color: "#FF0000" }
}

function getText(selectorClass) {
  return document.querySelector(`#block-container-assets .editor-social-icons-${selectorClass}`).innerText
}

function getIcon(iconName) {
  return document.querySelector(`#block-container-assets .icon-${iconName}`).innerHTML
}

function createUrlInput(
  placeholder,
  value = "",
  className = "w-full px bg-white hover:bg-emerald-100 text-black mb-6"
) {
  const input = document.createElement("input")
  input.type = "url"
  input.required = true
  input.placeholder = placeholder
  input.className = className
  if (value) input.value = value
  return input
}

function createColorInputWithLabel(labelText, defaultValue = defaultBgColor) {
  const label = document.createElement("label")
  label.textContent = labelText
  label.className = "block text-sm font-medium mb-2"

  const input = document.createElement("input")
  input.type = "color"
  input.value = defaultValue
  input.className = "w-full h-10 border border-gray-300 rounded mb-4"

  return { label, input }
}

function createIconColorSelect(selectedValue = "white") {
  const label = document.createElement("label")
  label.textContent = getText("icon-color-label")
  label.className = "block text-sm font-medium mb-2"

  const select = document.createElement("select")
  select.className = "w-full px bg-white hover:bg-emerald-100 text-black mb-6"
  select.innerHTML = `
    <option value="black">${getText("color-black")}</option>
    <option value="white">${getText("color-white")}</option>
  `
  select.value = selectedValue

  return { label, select }
}

export default class SocialIcons {
  constructor({ data, api, block }) {
    this.api = api
    this.block = block

    this.data = {
      social_icons: (data && data.social_icons) || [],
      alignment: (data && data.alignment) || defaultAlignment,
      size: (data && data.size) || defaultIconSize
    }

    this.wrapper = document.createElement("div")
    this.drawView()
  }

  render() {
    return this.wrapper
  }

  drawView() {
    this.wrapper.innerHTML = ""
    this.wrapper.className = "social-icons-block"

    try {
      if (this.isEmpty()) {
        this.renderEmptyState()
      } else {
        this.renderSocialIcons()
      }
    } catch (error) {
      console.error("Error rendering social icons", error)
      this.wrapper.innerHTML = "<div class=\"text-red-500\">Error rendering social icons</div>"
    }

    return this.wrapper
  }

  renderEmptyState() {
    const addButton = document.createElement("button")
    addButton.type = "button"
    addButton.textContent = getText("add-button")
    addButton.className = "button button--cta button--large transition-colors"
    addButton.addEventListener("click", (e) => {
      e.preventDefault()
      this.showNetworkSelector()
    })
    this.wrapper.appendChild(addButton)
  }

  renderSocialIcons() {
    const iconsContainer = document.createElement("div")
    const alignmentClasses = {
      left: "justify-start",
      center: "justify-center",
      right: "justify-end"
    }
    iconsContainer.className = `flex flex-wrap items-center ${
      alignmentClasses[this.data.alignment] || "justify-center"
    }`
    iconsContainer.style.gap = `${this.data.size / 4}px`

    this.data.social_icons.forEach((socialIcon, index) => {
      const iconWrapper = document.createElement("div")
      iconWrapper.className = "relative group"

      // Create icon display
      const iconElement = document.createElement("div")
      iconElement.className = `rounded flex items-center justify-center cursor-pointer transition-colors`
      iconElement.style.padding = `${this.data.size / 4}px`

      // Apply background color
      const backgroundColor = socialIcon.backgroundColor
      if (backgroundColor) {
        iconElement.style.backgroundColor = backgroundColor
        iconElement.style.opacity = "0.9"
        iconElement.addEventListener("mouseenter", () => {
          iconElement.style.opacity = "1"
        })
        iconElement.addEventListener("mouseleave", () => {
          iconElement.style.opacity = "0.9"
        })
      } else {
        iconElement.className += " bg-gray-200 hover:bg-gray-300"
      }

      if (socialIcon.icon.startsWith("http")) {
        // Custom icon
        const img = document.createElement("img")
        img.src = socialIcon.icon
        img.alt = socialIcon.name
        img.width = `${this.data.size}px`
        img.height = `${this.data.size}px`
        iconElement.appendChild(img)
      } else {
        // Predefined icon from block-container-assets
        const iconHTML = getIcon(socialIcon.icon)
        if (iconHTML) {
          iconElement.innerHTML = iconHTML
          // Apply icon color based on background
          const svgElement = iconElement.querySelector("svg")
          if (svgElement) {
            const iconColor = socialIcon.iconColor
            svgElement.style.fill = iconColor
            svgElement.style.width = `${this.data.size}px`
            svgElement.style.height = `${this.data.size}px`
          }
        }
      }

      // Add click handler to edit
      iconElement.addEventListener("click", (e) => {
        e.preventDefault()
        this.editSocialIcon(index)
      })

      // Delete button
      const deleteButton = document.createElement("button")
      deleteButton.type = "button"
      deleteButton.textContent = "×"
      deleteButton.className =
        "absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white rounded-full text-xs opacity-0 group-hover:opacity-100 transition-opacity"
      deleteButton.addEventListener("click", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this.removeSocialIcon(index)
      })

      iconWrapper.appendChild(iconElement)
      iconWrapper.appendChild(deleteButton)
      iconsContainer.appendChild(iconWrapper)
    })

    // Add button for adding more icons
    const addButton = document.createElement("button")
    addButton.type = "button"
    addButton.textContent = "+"
    addButton.className = `bg-gray-200 rounded flex items-center justify-center hover:bg-gray-300 transition`
    addButton.style.width = `${this.data.size}px`
    addButton.style.height = `${this.data.size}px`
    addButton.style.padding = `${this.data.size / 4}px`
    addButton.addEventListener("click", (e) => {
      e.preventDefault()
      this.showNetworkSelector()
    })
    iconsContainer.appendChild(addButton)

    this.wrapper.appendChild(iconsContainer)
  }

  showNetworkSelector() {
    const select = document.createElement("select")
    select.className = "w-full px bg-white hover:bg-emerald-100 text-black mb-6"

    const defaultOption = document.createElement("option")
    defaultOption.textContent = getText("select-site")
    select.appendChild(defaultOption)

    Object.keys(knownSites).forEach(siteKey => {
      const option = document.createElement("option")
      option.value = siteKey
      option.textContent = knownSites[siteKey].label
      select.appendChild(option)
    })

    const otherOption = document.createElement("option")
    otherOption.value = "other"
    otherOption.textContent = getText("other-custom")
    select.appendChild(otherOption)

    const modal = this.showModal(
      getText("choose-network-title"),
      [select],
      [
        {
          text: getText("continue-button"),
          className: "button button--cta button--large",
          handler: (e) => {
            e.preventDefault()
            if (select.value) {
              this.closeModal(modal)
              if (select.value === "other") {
                this.showCustomNetworkInput()
              } else {
                const network = knownSites[select.value]
                this.showLinkInput(network.label, select.value, network.color)
              }
            }
          }
        },
        {
          text: getText("cancel-button"),
          className: "button button--text button--large",
          handler: (e) => {
            e.preventDefault()
            this.closeModal(modal)
          }
        }
      ]
    )
  }

  showLinkInput(networkName, iconKey, bgColor) {
    const input = createUrlInput(getText("url-placeholder"))
    const { label: bgLabel, input: bgInput } = createColorInputWithLabel(getText("background-color-label"), bgColor)
    const { label: iconLabel, select: iconSelect } = createIconColorSelect()

    const addProfileTitle = getText("add-profile-title").replace("%{network}", networkName)
    const modal = this.showModal(addProfileTitle, [
      input,
      bgLabel,
      bgInput,
      iconLabel,
      iconSelect
    ], [
      {
        text: getText("add-button-modal"),
        className: "button button--cta button--large",
        handler: (e) => {
          e.preventDefault()
          if (input.checkValidity() && input.value.trim()) {
            this.addSocialIcon(networkName, iconKey, input.value.trim(), bgInput.value, iconSelect.value)
            this.closeModal(modal)
          } else {
            input.reportValidity()
          }
        }
      },
      {
        text: getText("cancel-button"),
        className: "button button--text button--large",
        handler: (e) => {
          e.preventDefault()
          this.closeModal(modal)
        }
      }
    ])

    input.focus()

    // Handle enter key
    input.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        e.preventDefault()
        if (input.checkValidity() && input.value.trim()) {
          this.addSocialIcon(networkName, iconKey, input.value.trim(), bgInput.value, iconSelect.value)
          this.closeModal(modal)
        } else {
          input.reportValidity()
        }
      }
    })
  }

  showCustomNetworkInput() {
    const nameInput = document.createElement("input")
    nameInput.type = "text"
    nameInput.required = true
    nameInput.placeholder = getText("platform-name-placeholder")
    nameInput.className = "w-full px-3 py-2 border border-gray-300 rounded mb-3"

    const iconInput = createUrlInput(
      getText("icon-url-placeholder"),
      "",
      "w-full px-3 py-2 border border-gray-300 rounded mb-3"
    )

    const linkInput = createUrlInput(
      getText("profile-url-placeholder"),
      "",
      "w-full px-3 py-2 border border-gray-300 rounded mb-3"
    )

    const { label: bgLabel, input: bgInput } = createColorInputWithLabel(getText("background-color-label"))

    const modal = this.showModal(
      getText("add-custom-title"),
      [
        nameInput,
        iconInput,
        linkInput,
        bgLabel,
        bgInput
      ],
      [
        {
          text: getText("add-button-modal"),
          className: "button button--cta button--large",
          handler: (e) => {
            e.preventDefault()
            if (
              nameInput.checkValidity() && iconInput.checkValidity() && linkInput.checkValidity()
              && nameInput.value.trim() && iconInput.value.trim() && linkInput.value.trim()
            ) {
              this.addSocialIcon(
                nameInput.value.trim(),
                iconInput.value.trim(),
                linkInput.value.trim(),
                bgInput.value,
                "white"
              )
              this.closeModal(modal)
            } else {
              if (!nameInput.checkValidity()) nameInput.reportValidity()
              else if (!iconInput.checkValidity()) iconInput.reportValidity()
              else if (!linkInput.checkValidity()) linkInput.reportValidity()
            }
          }
        },
        {
          text: getText("cancel-button"),
          className: "button button--text button--large",
          handler: (e) => {
            e.preventDefault()
            this.closeModal(modal)
          }
        }
      ]
    )

    nameInput.focus()
  }

  editSocialIcon(index) {
    const socialIcon = this.data.social_icons[index]
    const isCustom = socialIcon.icon.startsWith("http")

    if (isCustom) {
      this.showEditCustomNetworkInput(index, socialIcon)
    } else {
      this.showEditLinkInput(index, socialIcon)
    }
  }

  showEditLinkInput(index, socialIcon) {
    const input = createUrlInput(getText("url-placeholder"), socialIcon.link)
    const { label: bgLabel, input: bgInput } = createColorInputWithLabel(
      getText("background-color-label"),
      socialIcon.backgroundColor || defaultBgColor
    )
    const { label: iconLabel, select: iconSelect } = createIconColorSelect(socialIcon.iconColor || "white")

    const editProfileTitle = getText("edit-profile-title").replace("%{network}", socialIcon.name)
    const modal = this.showModal(editProfileTitle, [
      input,
      bgLabel,
      bgInput,
      iconLabel,
      iconSelect
    ], [
      {
        text: getText("save-button"),
        className: "button button--cta button--large",
        handler: (e) => {
          e.preventDefault()
          if (input.checkValidity() && input.value.trim()) {
            this.updateSocialIcon(
              index,
              socialIcon.name,
              socialIcon.icon,
              input.value.trim(),
              bgInput.value,
              iconSelect.value
            )
            this.closeModal(modal)
          } else {
            input.reportValidity()
          }
        }
      },
      {
        text: getText("cancel-button"),
        className: "button button--text button--large",
        handler: (e) => {
          e.preventDefault()
          this.closeModal(modal)
        }
      }
    ])

    input.focus()
    input.select()
  }

  showEditCustomNetworkInput(index, socialIcon) {
    const nameInput = document.createElement("input")
    nameInput.type = "text"
    nameInput.required = true
    nameInput.value = socialIcon.name
    nameInput.className = "w-full px-3 py-2 border border-gray-300 rounded mb-3"

    const iconInput = createUrlInput(
      getText("icon-url-placeholder"),
      socialIcon.icon,
      "w-full px-3 py-2 border border-gray-300 rounded mb-3"
    )

    const linkInput = createUrlInput(
      getText("profile-url-placeholder"),
      socialIcon.link,
      "w-full px-3 py-2 border border-gray-300 rounded mb-3"
    )

    const { label: bgLabel, input: bgInput } = createColorInputWithLabel(
      getText("background-color-label"),
      socialIcon.backgroundColor || defaultBgColor
    )

    const modal = this.showModal(
      getText("edit-custom-title"),
      [
        nameInput,
        iconInput,
        linkInput,
        bgLabel,
        bgInput
      ],
      [
        {
          text: getText("save-button"),
          className: "button button--cta button--large",
          handler: (e) => {
            e.preventDefault()
            if (
              nameInput.checkValidity() && iconInput.checkValidity() && linkInput.checkValidity()
              && nameInput.value.trim() && iconInput.value.trim() && linkInput.value.trim()
            ) {
              this.updateSocialIcon(
                index,
                nameInput.value.trim(),
                iconInput.value.trim(),
                linkInput.value.trim(),
                bgInput.value,
                "white"
              )
              this.closeModal(modal)
            } else {
              if (!nameInput.checkValidity()) nameInput.reportValidity()
              else if (!iconInput.checkValidity()) iconInput.reportValidity()
              else if (!linkInput.checkValidity()) linkInput.reportValidity()
            }
          }
        },
        {
          text: getText("cancel-button"),
          className: "button button--text button--large",
          handler: (e) => {
            e.preventDefault()
            this.closeModal(modal)
          }
        }
      ]
    )

    nameInput.focus()
    nameInput.select()
  }

  showModal(title, contentElements, actions = []) {
    const modal = document.createElement("div")
    modal.className = "fixed z-10 inset-0 overflow-y-auto bg-black/90 flex items-center justify-center"

    const modalContent = document.createElement("div")
    modalContent.className =
      "bg-gray-900 rounded-lg overflow-hidden shadow-xl transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full text-white p-8"

    const titleElement = document.createElement("h3")
    titleElement.textContent = title
    titleElement.className = "text-lg font-bold mb-4"
    modalContent.appendChild(titleElement)

    // Add content elements
    contentElements.forEach(element => {
      modalContent.appendChild(element)
    })

    // Add action buttons
    if (actions.length > 0) {
      const buttonContainer = document.createElement("div")
      buttonContainer.className = "flex flex-row-reverse justify-start gap-6"

      actions.forEach(action => {
        const button = document.createElement("button")
        button.type = "button"
        button.textContent = action.text
        button.className = action.className
        button.addEventListener("click", action.handler)
        buttonContainer.appendChild(button)
      })

      modalContent.appendChild(buttonContainer)
    }

    modal.appendChild(modalContent)
    document.body.appendChild(modal)

    // Close on backdrop click
    modal.addEventListener("click", (e) => {
      if (e.target === modal) {
        this.closeModal(modal)
      }
    })

    return modal
  }

  closeModal(modal) {
    document.body.removeChild(modal)
  }

  addSocialIcon(name, icon, link, backgroundColor = defaultBgColor, iconColor = "#FFFFFF") {
    const socialIcon = {
      name,
      icon,
      link,
      backgroundColor: backgroundColor || defaultBgColor,
      iconColor: iconColor || "#FFFFFF"
    }
    this.data.social_icons.push(socialIcon)
    this.drawView()
    this.block.dispatchChange()
  }

  updateSocialIcon(index, name, icon, link, backgroundColor = null, iconColor = null) {
    const existingIcon = this.data.social_icons[index]
    this.data.social_icons[index] = {
      name,
      icon,
      link,
      backgroundColor: backgroundColor !== null ? backgroundColor : (existingIcon.backgroundColor || defaultBgColor),
      iconColor: iconColor !== null ? iconColor : (existingIcon.iconColor || "#FFFFFF")
    }
    this.drawView()
    this.block.dispatchChange()
  }

  removeSocialIcon(index) {
    this.data.social_icons.splice(index, 1)
    this.drawView()
    this.block.dispatchChange()
  }

  isEmpty() {
    return !this.data.social_icons || this.data.social_icons.length === 0
  }

  save(_blockContent) {
    return {
      social_icons: this.data.social_icons,
      alignment: this.data.alignment,
      size: this.data.size
    }
  }

  validate(savedData) {
    if (!savedData) {
      return false
    }
    return true
  }

  updateAlignment(alignment) {
    this.data.alignment = alignment
    this.drawView()
    this.block.dispatchChange()
  }

  setSize(size) {
    this.data.size = size
    this.drawView()
    this.block.dispatchChange()
  }

  renderSettings() {
    const alignmentSettings = [
      {
        name: "left",
        icon: getIcon("align-left"),
        action: () => this.updateAlignment("left")
      },
      {
        name: "center",
        icon: getIcon("align-center"),
        action: () => this.updateAlignment("center")
      },
      {
        name: "right",
        icon: getIcon("align-right"),
        action: () => this.updateAlignment("right")
      }
    ]

    const sizeSettings = [
      { name: "small", size: 16, iconSize: "w-2 h-2" },
      { name: "medium", size: 24, iconSize: "w-3 h-3" },
      { name: "large", size: 32, iconSize: "w-4 h-4" }
    ]

    const allSettings = [
      ...alignmentSettings.map(setting => ({
        icon: setting.icon,
        label: getText(`align-${setting.name}`),
        onActivate: setting.action,
        closeOnActivate: true,
        isActive: this.data.alignment === setting.name
      })),

      ...sizeSettings.map(setting => ({
        label: getText(`size-${setting.name}`),
        icon: `<div class="${setting.iconSize} bg-gray-800 rounded-full"></div>`,
        onActivate: () => this.setSize(setting.size),
        isActive: this.data.size === setting.size
      }))
    ]

    return allSettings
  }

  static get pasteConfig() {
    return {
      tags: ["A"],
      patterns: {
        social:
          /https?:\/\/(www\.)?(facebook|instagram|twitter|x\.com|linkedin|github|youtube|tiktok|discord|mastodon|bluesky|reddit|signal|slack|snapchat|soundcloud|threads|twitch|whatsapp|xing)\.[\w\/\.\-_]+/
      }
    }
  }

  static get contentless() {
    return true
  }

  static get toolbox() {
    return {
      title: getText("title"),
      icon: getIcon("thumb-up")
    }
  }
}
