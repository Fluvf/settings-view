path = require 'path'
PackageDetailView = require '../lib/package-detail-view'
PackageManager = require '../lib/package-manager'
SettingsView = require '../lib/settings-view'
PackageKeymapView = require '../lib/package-keymap-view'
PackageSnippetsView = require '../lib/package-snippets-view'
_ = require 'underscore-plus'

describe "InstalledPackageView", ->
  beforeEach ->
    spyOn(PackageManager.prototype, 'loadCompatiblePackageVersion').andCallFake ->

  it "displays the grammars registered by the package", ->
    settingsPanels = null
    snippetservice = null

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    waitsForPromise ->
      atom.packages.activatePackage('snippets').then (pack) ->
        snippetsService = pack.mainModule.snippets()

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), snippetsService)
      settingsPanels = view.element.querySelectorAll('.package-grammars .settings-panel')

      waitsFor ->
        children = Array.from(settingsPanels).map((s) -> s.children.length)
        childrenCount = children.reduce(((a, b) -> a + b), 0)
        childrenCount is 2

      expect(settingsPanels[0].querySelector('.grammar-scope').textContent).toBe 'Scope: source.a'
      expect(settingsPanels[0].querySelector('.grammar-filetypes').textContent).toBe 'File Types: .a, .aa, a'

      expect(settingsPanels[1].querySelector('.grammar-scope').textContent).toBe 'Scope: source.b'
      expect(settingsPanels[1].querySelector('.grammar-filetypes').textContent).toBe 'File Types: '

      expect(settingsPanels[2]).toBeUndefined()

  it "displays the snippets registered by the package", ->
    snippetsTable = null
    snippetservice = null

    # Relies on behavior not present in the snippets package before 1.33.
    # TODO: These tests should always run once 1.33 is released.
    shouldRunScopeTest = parseFloat(atom.getVersion()) >= 1.33

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    waitsForPromise ->
      atom.packages.activatePackage('snippets').then (pack) ->
        snippetsService = pack.mainModule.snippets()

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), snippetsService)
      snippetsTable = view.element.querySelector('.package-snippets-table tbody')

    waitsFor 'snippets table children to contain 2 items', ->
      snippetsTable.children.length >= 2

    runs ->
      expect(snippetsTable.querySelector('tr:nth-child(1) td:nth-child(1)').textContent).toBe 'b'
      expect(snippetsTable.querySelector('tr:nth-child(1) td:nth-child(2)').textContent).toBe 'BAR'
      expect(snippetsTable.querySelector('tr:nth-child(1) td.snippet-scope-name').textContent).toBe '.b.source' if shouldRunScopeTest

      expect(snippetsTable.querySelector('tr:nth-child(2) td:nth-child(1)').textContent).toBe 'f'
      expect(snippetsTable.querySelector('tr:nth-child(2) td:nth-child(2)').textContent).toBe 'FOO'
      expect(snippetsTable.querySelector('tr:nth-child(2) td.snippet-scope-name').textContent).toBe '.a.source' if shouldRunScopeTest

  describe "when a snippet body is viewed", ->
    it "shows a tooltip", ->
      tooltipCalls = []
      view = null
      snippetsTable = null
      snippetsService = null

      waitsForPromise ->
        atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

      waitsForPromise ->
        atom.packages.activatePackage('snippets').then (pack) ->
          snippetsService = pack.mainModule.snippets()

      runs ->
        pack = atom.packages.getActivePackage('language-test')
        view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), snippetsService)
        snippetsTable = view.element.querySelector('.package-snippets-table tbody')

      waitsFor 'snippets table children to contain 2 items', ->
        snippetsTable.children.length >= 2

      runs ->
        expect(view.element.ownerDocument.querySelector('.snippet-body-tooltip')).not.toExist()

        view.element.querySelector('.package-snippets-table tbody tr:nth-child(1) td.snippet-body .snippet-view-btn').click()
        expect(view.element.ownerDocument.querySelector('.snippet-body-tooltip')).toExist()


  # Relies on behavior not present in the snippets package before 1.33.
  # TODO: These tests should always run once 1.33 is released.
  if parseFloat(atom.getVersion()) >= 1.33
    describe "when a snippet is copied", ->
      [pack, card] = []
      snippetsTable = null
      snippetsService = null

      beforeEach ->
        waitsForPromise ->
          atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

        waitsForPromise ->
          atom.packages.activatePackage('snippets').then (pack) ->
            snippetsService = pack.mainModule.snippets()

        runs ->
          pack = atom.packages.getActivePackage('language-test')
          card = new PackageSnippetsView(pack, snippetsService)
          snippetsTable = card.element.querySelector('.package-snippets-table tbody')

        waitsFor 'snippets table children to contain 2 items', ->
          snippetsTable.children.length >= 2

      describe "when the snippets file ends in .cson", ->
        it "writes a CSON snippet to the clipboard", ->
          spyOn(snippetsService, 'userSnippetsPath').andReturn('snippets.cson')
          card.element.querySelector('.package-snippets-table tbody tr:nth-child(1) td.snippet-body .snippet-copy-btn').click()
          expect(atom.clipboard.read()).toBe """
            \n'.b.source':
              'BAR':
                'prefix': 'b'
                'body': 'bar?\\nline two'\n
          """

      describe "when the snippets file ends in .json", ->
        it "writes a JSON snippet to the clipboard", ->
          spyOn(snippetsService, 'userSnippetsPath').andReturn('snippets.json')
          card.element.querySelector('.package-snippets-table tbody tr:nth-child(1) td.snippet-body .btn:nth-child(2)').click()
          expect(atom.clipboard.read()).toBe """
            \n  ".b.source": {
                "BAR": {
                  "prefix": "b",
                  "body": "bar?\\nline two"
                }
              }\n
          """

  describe "when the snippets toggle is clicked", ->
    it "sets the packagesWithSnippetsDisabled config to include the package name", ->
      [pack, card] = []
      snippetsService = []

      waitsForPromise ->
        atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

      waitsForPromise ->
        atom.packages.activatePackage('snippets').then (pack) ->
          snippetsService = pack.mainModule.snippets()

      waitsFor 'snippets to load', -> snippetsModule.provideSnippets().bundledSnippetsLoaded()

      runs ->
        pack = atom.packages.getActivePackage('language-test')
        card = new PackageSnippetsView(pack, snippetsService)
        jasmine.attachToDOM(card.element)

        card.refs.snippetToggle.click()
        expect(card.refs.snippetToggle.checked).toBe false
        expect(_.include(atom.config.get('core.packagesWithSnippetsDisabled') ? [], 'language-test')).toBe true

      waitsFor 'snippets table to update', ->
        card.refs.snippets.classList.contains('text-subtle')

      runs ->
        card.refs.snippetToggle.click()
        expect(card.refs.snippetToggle.checked).toBe true
        expect(_.include(atom.config.get('core.packagesWithSnippetsDisabled') ? [], 'language-test')).toBe false

      waitsFor 'snippets table to update', ->
        not card.refs.snippets.classList.contains('text-subtle')

  it "does not display keybindings from other platforms", ->
    keybindingsTable = null
    snippetsService = null

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    waitsForPromise ->
      atom.packages.activatePackage('snippets').then (pack) ->
        snippetsService = pack.mainModule.snippets()

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), snippetsService)
      keybindingsTable = view.element.querySelector('.package-keymap-table tbody')
      expect(keybindingsTable.children.length).toBe 1

  describe "when the keybindings toggle is clicked", ->
    it "sets the packagesWithKeymapsDisabled config to include the package name", ->
      waitsForPromise ->
        atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

      runs ->
        pack = atom.packages.getActivePackage('language-test')
        card = new PackageKeymapView(pack)
        jasmine.attachToDOM(card.element)

        card.refs.keybindingToggle.click()
        expect(card.refs.keybindingToggle.checked).toBe false
        expect(_.include(atom.config.get('core.packagesWithKeymapsDisabled') ? [], 'language-test')).toBe true

        if atom.keymaps.build?
          keybindingRows = card.element.querySelectorAll('.package-keymap-table tbody.text-subtle tr')
          expect(keybindingRows.length).toBe 1

        card.refs.keybindingToggle.click()
        expect(card.refs.keybindingToggle.checked).toBe true
        expect(_.include(atom.config.get('core.packagesWithKeymapsDisabled') ? [], 'language-test')).toBe false

        if atom.keymaps.build?
          keybindingRows = card.element.querySelectorAll('.package-keymap-table tbody tr')
          expect(keybindingRows.length).toBe 1

  describe "when a keybinding is copied", ->
    [pack, card] = []

    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

      runs ->
        pack = atom.packages.getActivePackage('language-test')
        card = new PackageKeymapView(pack)

    describe "when the keybinding file ends in .cson", ->
      it "writes a CSON snippet to the clipboard", ->
        spyOn(atom.keymaps, 'getUserKeymapPath').andReturn 'keymap.cson'
        card.element.querySelector('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          'test':
            'cmd-g': 'language-test:run'
        """

    describe "when the keybinding file ends in .json", ->
      it "writes a JSON snippet to the clipboard", ->
        spyOn(atom.keymaps, 'getUserKeymapPath').andReturn 'keymap.json'
        card.element.querySelector('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          "test": {
            "cmd-g": "language-test:run"
          }
        """

  describe "when the package is active", ->
    it "displays the correct enablement state", ->
      packageCard = null
      snippetsService = null

      waitsForPromise ->
        atom.packages.activatePackage('status-bar')

      waitsForPromise ->
        atom.packages.activatePackage('snippets').then (pack) ->
          snippetsService = pack.mainModule.snippets()

      runs ->
        expect(atom.packages.isPackageActive('status-bar')).toBe(true)
        pack = atom.packages.getLoadedPackage('status-bar')
        view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), snippetsService)
        packageCard = view.element.querySelector('.package-card')

      runs ->
        # Trigger observeDisabledPackages() here
        # because it is not default in specs
        atom.packages.observeDisabledPackages()
        atom.packages.disablePackage('status-bar')
        expect(atom.packages.isPackageDisabled('status-bar')).toBe(true)
        expect(packageCard.classList.contains('disabled')).toBe(true)

  describe "when the package is not active", ->
    it "displays the correct enablement state", ->
      snippetsService = null

      waitsForPromise ->
        atom.packages.activatePackage('snippets').then (pack) ->
          snippetsService = pack.mainModule.snippets()

      atom.packages.loadPackage('status-bar')
      expect(atom.packages.isPackageActive('status-bar')).toBe(false)
      pack = atom.packages.getLoadedPackage('status-bar')
      view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), snippetsService)
      packageCard = view.element.querySelector('.package-card')

      # Trigger observeDisabledPackages() here
      # because it is not default in specs
      atom.packages.observeDisabledPackages()
      atom.packages.disablePackage('status-bar')
      expect(atom.packages.isPackageDisabled('status-bar')).toBe(true)
      expect(packageCard.classList.contains('disabled')).toBe(true)

    it "still loads the config schema for the package", ->
      snippetsService = null

      waitsForPromise ->
        atom.packages.activatePackage('snippets').then (pack) ->
          snippetsService = pack.mainModule.snippets()

      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))

      waitsFor ->
        atom.packages.isPackageLoaded('package-with-config') is true

      runs ->
        expect(atom.config.get('package-with-config.setting')).toBe undefined

        pack = atom.packages.getLoadedPackage('package-with-config')
        new PackageDetailView(pack, new SettingsView(), new PackageManager(), snippetsService)

        expect(atom.config.get('package-with-config.setting')).toBe 'something'

  describe "when the package was not installed from atom.io", ->
    normalizePackageDataReadmeError = 'ERROR: No README data found!'

    it "still displays the Readme", ->
      snippetsService = null

      waitsForPromise ->
        atom.packages.activatePackage('snippets').then (pack) ->
          snippetsService = pack.mainModule.snippets()

      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-readme'))

      waitsFor ->
        atom.packages.isPackageLoaded('package-with-readme') is true

      runs ->
        pack = atom.packages.getLoadedPackage('package-with-readme')
        expect(pack.metadata.readme).toBe normalizePackageDataReadmeError

        view = new PackageDetailView(pack, new SettingsView(), new PackageManager(), snippetsService)
        expect(view.refs.sections.querySelector('.package-readme').textContent).not.toBe normalizePackageDataReadmeError
        expect(view.refs.sections.querySelector('.package-readme').textContent.trim()).toContain 'I am a Readme!'
