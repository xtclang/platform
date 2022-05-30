import React, {Component} from 'react';

class Home extends Component {

    constructor() {
        super();

        this.state = {
                userId:  "<none>",
                loading: -1,        // half seconds from the moment the load request started
                url:     null,      // the url for the loaded application
                error:   null
                };
          this.loadAction = this.loadRequest.bind(this);
          this.loadResult = React.createRef();
          }

    componentDidMount() {
        fetch('host/userId')
            .then(response => response.text())
            .then(data => this.setState(state => ({userId: data})));
        }

    tick() {
        console.log('tick.'.padEnd(this.state.loading, '.') + ' ' + this.state.lading);
        this.setState(state => ({loading: state.loading + 1}));
        }

    loadRequest(event) {
        this.setState(state => {return {loading: 0}});
        this.interval = setInterval(() => this.tick(), 500);

        event.preventDefault();
        const requestOptions = {
            method:  'post',
            headers: {'Content-Type':'text/html'},
            body:    {}
            };

        var uri = '/host/load?app=' + this.loadResult.current.value +
                ',domain=shop.'+ this.state.userId + '.user';
        fetch(uri, requestOptions)
            .then(response =>
                {
                if (response.status >= 400)
                    {
                    throw new Error(response.statusText);
                    }
                else
                    {
                    return response.text();
                    }
                })
            .then(data => this.setState(state => ({loading: -1, url: data, error: null})),
                  err  => this.setState(state => ({loading: -1, url: null, error: err.message})))
            .finally(() => clearInterval(this.interval));
      }

    render()
        {
        const url  = this.state.url;
        let   link;

        if (url != null)
            {
            link = <a href={url} target="_blank">run application</a>;
            }
        else if (this.state.loading >= 0)
            {
            link = 'loading.'.padEnd(this.state.loading, '.');
            }
        else if (this.state.error != null)
            {
            const style = {color: 'red'};
            link = <span style={style}>{this.state.error}</span>;
            }
        else
            {
            link = "";
            }

        return (
            <div>
                <h2>Welcome to XQIZ.IT portal</h2>
                User: {this.state.userId}

                <p/>

                <form onSubmit={this.loadAction}>
                    <label> Module name:&nbsp;
                        <input type="text" ref={this.loadResult} defaultValue="welcome"/>
                    </label>
                    &nbsp; <input type="submit" value="load app" />
                    &nbsp; {link}
                </form>
            </div>
            );
        };
    }

export default Home;