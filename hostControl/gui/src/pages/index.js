import React, {Component} from 'react';

class Home extends Component {

    constructor() {
      super();

      this.state = {userId: "???"};
      }

    componentDidMount() {
      fetch('host/userId')
        .then(response => response.text())
        .then(data => this.setState(state => ({userId: data})));
    }
    render()
      {
      return (
        <div>
        <h1>Welcome to XQIZ.IT Hosting Portal</h1>
        User: {this.state.userId}
        </div>
        );
      };
  }

export default Home;