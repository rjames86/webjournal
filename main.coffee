d = React.DOM

FileList = React.createFactory React.createClass
  getInitialState: ->
    fileList: []
    createFile: _.debounce(@createFile, 500, true)

  componentDidMount: ->
    @props.dbClient.authenticate (error, data) =>
      @props.dbClient.readdir "/", (error, entries) =>
        if error
          console.log error
          return
        @setState fileList: entries

  createFile: ->
    now = (new Date()).toISOString().replace(/:/g, ".")
    fileName = "#{now}.txt"
    @props.dbClient.authenticate (error, data) =>
      @props.dbClient.writeFile fileName, " ", (error, stat) =>
        console.log fileName
        currentFileList = @state.fileList
        currentFileList.push fileName
        @props.onSelect fileName
        @setState currentFileList

  render: ->
    d.ul {className: "list-group"},
      d.li {className: "list-group-item", onClick: @state.createFile }, "Create New Entry"
      @state.fileList.map (entry, i) =>
        d.li {className: "list-group-item", key: i, onClick: => @props.onSelect entry }, entry



RenderedCommentBox = React.createFactory React.createClass
  render: ->
    raw_markup = marked(@props.comment, {sanitize: true})

    d.div {},
      d.span {dangerouslySetInnerHTML: {__html: raw_markup}}

CommentBox = React.createFactory React.createClass
  getInitialState: ->
    uploader: _.throttle(@uploadToDropbox, 5000)
    comment: ""
    geolocation: null
    userInfo: {}
    lastUpdated: ""

  getDefaultProps: ->
    fileToLoad: ""

  componentDidMount: ->
    @props.dbClient.authenticate (error, data) =>
      console.log(error) if error
      @props.dbClient.getAccountInfo (error, userInfo) =>
        @setState userInfo: userInfo
      if @props.fileToLoad
        console.log "did mount filetoload", @props.fileToLoad
        @props.dbClient.readFile @props.fileToLoad, (error, data) =>
          @setState comment: data, =>
            @props.setCompiledComment @compileText()

  componentWillReceiveProps: (nextProps) ->
    console.log "nextProps", nextProps.fileToLoad
    if nextProps.fileToLoad != @props.fileToLoad
      console.log "should be loading new file"
      @props.dbClient.authenticate (error, data) =>
        @props.dbClient.readFile nextProps.fileToLoad, (error, data) =>
          @setState comment: data, =>
            @props.setCompiledComment @compileText()

  compileText: ->
    to_ret = ""
    if @state.geolocation
      to_ret = """
Location: #{@state.geolocation.latitude}, #{@state.geolocation.longitude}
"""
    to_ret = to_ret + "\n\n" + @state.comment
    to_ret

  uploadToDropbox: ->
    console.log "uploadToDropbox"
    @props.dbClient.writeFile(@props.fileToLoad, @compileText(), (error, stat) =>
      if error
        console.log error
      @setState lastUpdated: stat.modifiedAt
    )

  getLocation: ->
    if navigator.geolocation
      navigator.geolocation.getCurrentPosition((position) =>
        console.log position.coords
        @setState geolocation: {latitude: position.coords.latitude, longitude: position.coords.longitude}
      )

  handleChange: (e) ->
    @setState comment: e.target.value, =>
      @props.setCompiledComment @compileText()
    @state.uploader()

  render: ->
    d.div {},
      # d.button {onClick: @getLocation}, "Click me!"
      d.div {},
        d.p {}, "Hello #{@state.userInfo.name}"
        d.textarea {cols: 80, rows: 20, onChange: @handleChange, value: @state.comment}
        d.p {}, "Last Updated: #{@state.lastUpdated}"


Page = React.createClass
  getInitialState: ->
    currentFile: ""
    compiledComment: ""

  onSelect: (file) ->
    console.log "onselect", file
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

