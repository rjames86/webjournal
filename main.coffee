d = React.DOM

FileList = React.createFactory React.createClass
  getInitialState: ->
    fileList: []
    createFile: _.debounce(@createFile, 500, true)
    selectedFile: ""

  newFileText: ->
    "Date Created: #{new Date()}\n"

  componentDidMount: ->
    @props.dbClient.authenticate (error, data) =>
      @props.dbClient.readdir "/", (error, entries) =>
        @setState fileList: entries

  createFile: ->
    now = (new Date()).toISOString().replace(/:/g, ".")
    fileName = "#{now}.txt"
    currentFileList = @state.fileList
    currentFileList.unshift fileName
    @setState _.extend currentFileList, {selectedFile: fileName}

    @props.dbClient.authenticate (error, data) =>
      @props.dbClient.writeFile fileName, @newFileText(), =>
        @props.onSelect fileName

  render: ->
    d.ul {className: "list-group"},
      d.li {className: "list-group-item", onTouchEnd: @state.createFile, onClick: @state.createFile }, "Create New Entry"
      @state.fileList.map (entry, i) =>
        isActive = if @state.selectedFile == entry then 'active' else ''
        d.li {
          key: i
          onClick: =>
            @setState selectedFile: entry
            @props.onSelect entry
          onTouchEnd: =>
            @setState selectedFile: entry
            @props.onSelect entry
          className: "hidden-xs list-group-item #{isActive}"
        }, entry

RenderedCommentBox = React.createFactory React.createClass
  render: ->
    raw_markup = marked(@props.comment, {sanitize: true})

    d.div {},
      d.span {dangerouslySetInnerHTML: {__html: raw_markup}}

CommentBox = React.createFactory React.createClass
  getInitialState: ->
    _.extend(userInfo: {name: "there"}, @nullState())

  nullState: ->
    uploader: _.throttle(@uploadToDropbox, 5000)
    comment: ""
    geolocation: null
    lastUpdated: ""

  getDefaultProps: ->
    fileToLoad: ""

  componentDidMount: ->
    @props.dbClient.authenticate (error, data) =>
      @props.dbClient.getAccountInfo (error, userInfo) =>
        @setState userInfo: userInfo
      if @props.fileToLoad
        @setState comment: "Loading..."
        @props.dbClient.readFile @props.fileToLoad, (error, data) =>
          @setState _.extend(@nullState(), {comment: data}), =>
            @props.setCompiledComment @compileText()

  componentWillReceiveProps: (nextProps) ->
    if nextProps.fileToLoad != @props.fileToLoad
      @uploadToDropbox()
      @setState comment: "Loading..."
      @props.dbClient.authenticate (error, data) =>
        @props.dbClient.readFile nextProps.fileToLoad, (error, data) =>
          @setState _.extend(@nullState(), {comment: data}), =>
            @props.setCompiledComment @compileText()

  compileText: ->
    to_ret = @state.comment
    if @state.geolocation
      to_ret = "Location: #{@state.geolocation.latitude}, #{@state.geolocation.longitude}  \n\n" + @state.comment
    to_ret

  uploadToDropbox: ->
    @props.dbClient.writeFile(@props.fileToLoad, @compileText(), (error, stat) =>
      @setState lastUpdated: stat.modifiedAt
    )

  getLocation: ->
    if navigator.geolocation
      navigator.geolocation.getCurrentPosition (position) =>
        @setState(
          geolocation: {
            latitude: position.coords.latitude
            longitude: position.coords.longitude
          }, => @props.setCompiledComment @compileText())


  buttonOptions: ->
    d.div {className: "btn-group", role: "group"},
      if @state.geolocation
        d.button {
          type: "button",
          className: "btn btn-default"
          onClick: =>
            @setState({geolocation: null}, => @props.setCompiledComment @compileText())
          onTouchEnd: =>
            @setState({geolocation: null}, => @props.setCompiledComment @compileText())
        }, "Remove Location"
      else
        d.button {
          type: "button",
          className: "btn btn-default"
          onClick: @getLocation
          onTouchEnd: @getLocation
        }, "Add Location"

  handleChange: (e) ->
    @setState comment: e.target.value, =>
      @props.setCompiledComment @compileText()
    @state.uploader()

  render: ->
    d.div {},
      d.div {},
        d.p {}, "Hello #{@state.userInfo.name}"
        d.textarea {cols: 80, rows: 20, onChange: @handleChange, value: @state.comment}
        d.p {}, "Last Updated: #{@state.lastUpdated}"
        @buttonOptions()


Page = React.createClass
  getInitialState: ->
    currentFile: ""
    compiledComment: ""

  onSelect: (file) ->
    @setState currentFile: file
  setCompiledComment: (comment) ->
    @setState compiledComment: comment

  render: ->
    d.div {className: "row"},
      d.div {className: "col-md-2"},
        FileList {dbClient: @props.dbClient, onSelect: @onSelect}
      d.div {className: "col-md-5"},
        if @state.currentFile
          CommentBox {fileToLoad: @state.currentFile, dbClient: @props.dbClient, setCompiledComment: @setCompiledComment}
      d.div {className: "col-md-5"},
        RenderedCommentBox
          comment: @state.compiledComment

$ ->
  client = new Dropbox.Client key: ""
  element = React.createElement(Page, {dbClient: client}, null)
  React.render(
    element,
    document.getElementById('react')
  )

