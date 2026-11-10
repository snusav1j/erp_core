window.setTheme = (theme) ->
  document.documentElement.setAttribute('data-theme', theme)
  localStorage.setItem('theme', theme)

  surfaceColor = getComputedStyle(document.documentElement).getPropertyValue('--surface-color').trim()
  themeMeta = document.querySelector('meta[name="theme-color"]')

  themeMeta.setAttribute('content', surfaceColor) if themeMeta


window.toggleTheme = ->
  currentTheme = document.documentElement.getAttribute('data-theme') || 'light'
  setTheme(if currentTheme == 'dark' then 'light' else 'dark')


$(document).ready ->
  savedTheme = localStorage.getItem('theme') || 'light'
  setTheme(savedTheme)