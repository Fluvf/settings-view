/** @babel */
/** @jsx etch.dom */

import path from 'path'
import etch from 'etch'
import {CompositeDisposable, Disposable} from 'atom'

// View to display the snippets that a package has registered.
export default class PackageSnippetsView {
  constructor (pack, snippetsService) {
    this.pack = pack
    this.namespace = this.pack.name
    this.snippetsService = snippetsService
    this.packagePath = path.join(pack.path, path.sep)
    etch.initialize(this)
    this.disposables = new CompositeDisposable()
    this.updateSnippetsView()

    const packagesWithSnippetsDisabled = atom.config.get('core.packagesWithSnippetsDisabled') || []
    this.refs.snippetToggle.checked = !packagesWithSnippetsDisabled.includes(this.namespace)

    const changeHandler = (event) => {
      event.stopPropagation()
      const value = this.refs.snippetToggle.checked
      if (value) {
        atom.config.removeAtKeyPath('core.packagesWithSnippetsDisabled', this.namespace)
      } else {
        atom.config.pushAtKeyPath('core.packagesWithSnippetsDisabled', this.namespace)
      }
      this.updateSnippetsView()
    }

    this.refs.snippetToggle.addEventListener('change', changeHandler)
    this.disposables.add(new Disposable(() => { this.refs.snippetToggle.removeEventListener('change', changeHandler) }))
  }

  destroy () {
    this.disposables.dispose()
    return etch.destroy(this)
  }

  update () {}

  render () {
    return (
      <section className='section'>
        <div className='section-heading icon icon-code'>Snippets</div>
        <div className='checkbox'>
          <label for='toggleSnippets'>
            <input id='toggleSnippets' className='input-checkbox' type='checkbox' ref='snippetToggle' />
            <div className='setting-title'>Enable</div>
          </label>
          <div className='setting-description'>
            {'Disable this if you want to prevent this package’s snippets from appearing as suggestions or if you want to customize them in your snippets file.'}
          </div>
        </div>

        <table className='package-snippets-table table native-key-bindings text' tabIndex={-1}>
          <thead>
            <tr>
              <th>Trigger</th>
              <th>Name</th>
              <th>Scope</th>
              <th>Body</th>
            </tr>
          </thead>
          <tbody ref='snippets' />
        </table>
      </section>
    )
  }

  updateSnippetsView () {
    // Reset and hide our snippets element
    this.refs.snippets.innerHTML = ''

    this.element.style.display = 'none'

    const packagesWithSnippetsDisabled = atom.config.get('core.packagesWithSnippetsDisabled') || []
    if (packagesWithSnippetsDisabled.includes(this.namespace)) {
      this.refs.snippets.classList.add('text-subtle')
    } else {
      this.refs.snippets.classList.remove('text-subtle')
    }

    // Check if the package snippets can be generated and displayed
    if (!atom.packages.isPackageLoaded('snippets')) {
      return
    }

    // We need to ensure that 'activate' has been called on the snippets package
    // otherwise the loading of our package snippets might not have started
    atom.packages.getLoadedPackage('snippets').activationPromise
    .then(() => this.snippetsService.snippetsByPackage().get(this.pack))
    .then(snippets => {
      // Convert the object from the snippet format into something easier to use
      Object.entries(snippets)
        .flatMap(([scope, definitions]) => Object.entries(definitions)
          .map(([name, definition]) => ({ scope, name, ...definition })))
        // Sort snippets according to their prefixes
        .sort(({ prefix: a = '' }, { prefix: b = '' }) => a.localeCompare(b))
        // Create elements for each snippet
        .forEach(({ body = '', name = '', prefix = '', scope = '' }) => {
          const row = document.createElement('tr')

          const prefixTd = document.createElement('td')
          prefixTd.classList.add('snippet-prefix')
          prefixTd.textContent = prefix
          row.appendChild(prefixTd)

          const nameTd = document.createElement('td')
          nameTd.textContent = name
          row.appendChild(nameTd)

          const scopeTd = document.createElement('td')
          scopeTd.classList.add('snippet-scope-name')
          scopeTd.textContent = scope
          row.appendChild(scopeTd)

          const bodyTd = document.createElement('td')
          bodyTd.classList.add('snippet-body')
          row.appendChild(bodyTd)

          this.refs.snippets.appendChild(row)
          this.createButtonsForSnippetRow(bodyTd, { body, prefix, scope, name })
        })

      if (this.refs.snippets.children.length > 0) {
        this.element.style.display = ''
      }
    })
  }

  createButtonsForSnippetRow (td, {scope, body, name, prefix}) {
    let buttonContainer = document.createElement('div')
    buttonContainer.classList.add('btn-group', 'btn-group-xs')

    let viewButton = document.createElement('button')
    let copyButton = document.createElement('button')

    viewButton.setAttribute('type', 'button')
    viewButton.textContent = 'View'
    viewButton.classList.add('btn', 'snippet-view-btn')

    let tooltip = atom.tooltips.add(viewButton, {
      title: body,
      html: false,
      trigger: 'click',
      placement: 'auto left',
      'class': 'snippet-body-tooltip'
    })

    this.disposables.add(tooltip)

    copyButton.setAttribute('type', 'button')
    copyButton.textContent = 'Copy'
    copyButton.classList.add('btn', 'snippet-copy-btn')

    copyButton.addEventListener('click', (event) => {
      event.preventDefault()
      return this.writeSnippetToClipboard({scope, body, name, prefix})
    })

    buttonContainer.appendChild(viewButton)
    buttonContainer.appendChild(copyButton)

    td.appendChild(buttonContainer)
  }

  writeSnippetToClipboard ({scope, body, name, prefix}) {
    let content
    const extension = path.extname(this.snippetsService.userSnippetsPath())
    body = body.replace(/\n/g, '\\n').replace(/\t/g, '\\t')
    if (extension === '.cson') {
      body = body.replace(/'/g, `\\'`)
      content = `
'${scope}':
  '${name}':
    'prefix': '${prefix}'
    'body': '${body}'
`
    } else {
      body = body.replace(/"/g, `\\"`)
      content = `
  "${scope}": {
    "${name}": {
      "prefix": "${prefix}",
      "body": "${body}"
    }
  }
`
    }

    atom.clipboard.write(content)
  }
}
