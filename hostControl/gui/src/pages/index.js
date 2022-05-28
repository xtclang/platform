import React, {Component} from 'react';

class Home extends Component {

    constructor() {
      super();

      this.state      = {userId: "<none>", url: null};
      this.loadAction = this.loadRequest.bind(this);
      this.loadName   = React.createRef();
      }

    componentDidMount() {
      fetch('host/userId')
        .then(response => response.text())
        .then(data => this.setState(state => ({userId: data})));
      }

    loadRequest(event) {
      event.preventDefault();
      const requestOptions = {
          method:  'post',
          headers: {'Content-Type':'text/html'},
          body:    {}
        };
      var uri = '/host/load?app=' + this.loadName.current.value +
                ',domain=shop.'+ this.state.userId + '.user';
      fetch(uri, requestOptions)
        .then(response => response.text())
        .then(data => this.setState(state => ({url: data})));
    }

    render()
      {
      const url  = this.state.url;
      let   link = url == null
            ? ""
            : <a href={url} target="_blank">run application</a>;

      return (
        <div>
          <h2>Welcome to XQIZ.IT portal</h2>
          User: {this.state.userId}

          <p/>

          <form onSubmit={this.loadAction}>
            <label>
              Module name:&nbsp;
              <input type="text" ref={this.loadName} defaultValue="welcome"/>
            </label>
            &nbsp;
            <input type="submit" value="load app" />
            &nbsp;
            {link}
          </form>
        </div>
        );
      };
  }

export default Home;