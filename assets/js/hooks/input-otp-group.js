export default {
  mounted () {
    const otpInputs = Array.from(this.el.getElementsByClassName('input-otp'))
    const len = otpInputs.length

    const handleInput = (event) => {
      const input = event.currentTarget
      const i = otpInputs.indexOf(input)
      if (input.value && (i+1) % len) otpInputs[i + 1]?.focus()
      //TODO: if all filled in submit the form
    }

    const handleKeyDown = (event) => {
      const input = event.currentTarget
      const i = otpInputs.indexOf(input)
      if (!input.value && event.key === "Backspace" && i) otpInputs[i - 1]?.focus(); 
    }

    const handleKeyUp = (event) => {
      const input = event.currentTarget
      const i = otpInputs.indexOf(input)
      if (input.value && (i+1) == len) {
	otpInputs[i - 1]?.dispatchEvent(
	  new Event("input", {bubbles: true})
	)
	document.getElementById('btn-otp-submit').click()
      }
    }

    const handlePaste = (event) => {
      event.preventDefault()
      const clip = event.clipboardData.getData('text')
      const otp = clip.replace(/\s|-/g, "")
      const ch = [...otp]
      otpInputs.forEach((el, i) => el.value = ch[i]??"")
      otpInputs[Math.min(len, otp.length -1)]?.focus()
    }

    Array.from(otpInputs).forEach(input => {
      input.addEventListener("input", handleInput)
      input.addEventListener("keydown", handleKeyDown)
      input.addEventListener("keyup", handleKeyUp)
      input.addEventListener("paste", handlePaste)
    })
  }
}
