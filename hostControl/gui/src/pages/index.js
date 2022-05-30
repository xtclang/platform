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
          this.action      = this.sendRequest.bind(this);
          this.actionInput = React.createRef();
          }

    componentDidMount() {
        fetch('host/userId')
            .then(response => response.text())
            .then(data => this.setState(state => ({userId: data})));
        }

    tick() {
        this.setState(state => ({loading: state.loading + 1}));
        }

    sendRequest(event) {
        event.preventDefault();

        const domain = 'shop.'+ this.state.userId + '.user';
        const requestOptions = {
            method:  'post',
            headers: {'Content-Type':'text/html'},
            body:    {}
            };

        if (this.state.url == null)
            {
            // load application
            this.interval = setInterval(() => this.tick(), 500);
            this.setState(state => ({loading: 0}));

            var uri = '/host/load?app=' + this.actionInput.current.value + ',domain=' + domain;
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
        else
            {
            // unload application
            var uri = '/host/unload/' + domain;
            fetch(uri, requestOptions);

            this.setState(state => ({loading: -1, url: null, error: null}));
            }
      }

    render()
        {
        const url = this.state.url;
        let   link;
        let   actionText = 'Load application';

        if (url != null)
            {
            link       = <a href={url} target="_blank">run application</a>;
            actionText = 'Unload application';
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

                <form onSubmit={this.action}>
                    <label> Module name:&nbsp;
                        <input type="text" ref={this.actionInput} defaultValue="welcome"/>
                    </label>
                    &nbsp; <input type="submit" value={actionText} />
                    &nbsp; {link}
                </form>
            </div>
            );
        };
    }

export default Home;