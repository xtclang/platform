import React, {Component} from 'react';
import ReactModal from 'react-modal';

class AppInfo
    {
    constructor(name, domain, url = null, loading = -1, error = null)
        {
        this.name    = name;
        this.domain  = domain;
        this.url     = url; // the url for the loaded application
        this.error   = error;
        }
    }

class Home extends Component
    {
    constructor()
        {
        super();

        this.state = {
                userId:  "<none>",
                availableModules : [],
                registeredApps: [],
                showAdd: false,

                loadingIndex: -1,  // the index of the app being loaded
                loadingTicks: -1,  // half seconds from the moment the load request started
                };
        this.action = this.sendRequest.bind(this);

        this.showAddModule  = this.showAddModule.bind(this);
        this.closeAddModule = this.closeAddModule.bind(this);

        this.moduleInput = React.createRef();
        this.domainInput = React.createRef();
        }

    componentDidMount() {
        fetch('host/userId')
            .then(response => response.text())
            .then(data => this.setState(state => ({userId: data})));
        fetch('host/registeredApps')
            .then(response => response.json())
            .then(data => this.setState(state => ({registeredApps: data})));
        }

    tick(ix) {
        this.setState(state => ({loadingTicks: state.loadingTicks + 1}));
        }

    setInfo(ix, url, err)
        {
        this.setState(state => {
            let infos = state.registeredApps;
            let info  = infos[ix];

            info.url   = url;
            info.error = err;
            infos[ix]  = info;

            return {loadingIndex: -1, registeredApps: infos};
            });
        }

    sendRequest(ix)
        {
        if (this.state.loadingIndex != -1)
            {
            return;
            }

        const requestOptions = {
            method:  'post',
            headers: {'Content-Type':'text/html'},
            body:    {}
            };

        const info   = this.state.registeredApps[ix];
        const domain = info.domain;
        const url    = info.url == null ? null : info.url;

        if (url == null)
            {
            // load application
            this.setState(state => ({loadingIndex: ix, loadingTicks: 0}));
            this.interval = setInterval(() => this.tick(ix), 500);

            const request = '/host/load?app=' + info.name + ',domain=' + domain;
            fetch(request, requestOptions)
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
                .then(data => this.setInfo(ix, data, null),
                      err  => this.setInfo(ix, null, err.message))
                .finally(() => clearInterval(this.interval));
            }
        else
            {
            // unload application
            const request = '/host/unload/' + domain;
            fetch(request, requestOptions);

            this.setInfo(ix, null, null);
            }
      }

    showAddModule()
        {
        this.setState(state => ({showAdd: true}));

        fetch('host/availableModules')
            .then(response => response.json())
            .then(data => this.setState(state => ({availableModules: data})));
        }

    closeAddModule(action)
        {
        if (action == "add")
            {
            const moduleName = this.moduleInput.current.value;
            if (moduleName == "")
                {
                return;
                }

            const registeredApps = this.state.registeredApps;
            if (registeredApps.some(info => {return info.name == moduleName;}))
                {
                this.moduleInput.current.value = "";
                alert("Module already registered");
                return;
                }

            var domain = this.domainInput.current.value;
            if (domain == "")
                {
                domain = moduleName;
                }
            registeredApps.push(new AppInfo(moduleName, domain + '.' + this.state.userId + ".user"));
            this.setState(state => ({registeredApps: registeredApps, showAdd: false}));
            }
        else
            {
            this.setState(state => ({showAdd: false}));
            }
        }

    render()
        {
        const registeredApps   = this.state.registeredApps;
        const availableModules = this.state.availableModules.map((name, index) => <option key={index}>{name}</option>);
        let   list = [];
        for (var i = 0; i < registeredApps.length; i++)
            {
            const ix   = i;
            const info = registeredApps[i];
            const url  = info.url;

            let   link;
            let   actionText = 'Load application';

            if (url != null)
                {
                link       = <a href={url} target="_blank">run application</a>;
                actionText = 'Unload application';
                }
            else if (info.error != null)
                {
                link = <span style={{color: 'red'}}>{info.error}</span>;
                }
            else if (this.state.loadingIndex == ix)
                {
                link = 'loading.'.padEnd(this.state.loadingTicks, '.');
                }
            else
                {
                link = "";
                }

            list.push(
                <tr key={ix}>
                    <td>{info.name}</td>
                    <td>{info.domain}</td>
                    <td><input type="button" onClick={()=>{this.action(ix)}} value={actionText}/></td>
                    <td>{link}</td>
                </tr>
                );
            }

        return (
            <div>
                <h2>Welcome to XQIZ.IT portal</h2>
                <b>User:</b> {this.state.userId}

                <p/>
                <table><tbody>
                  <tr>
                    <td><b>Module</b></td>
                    <td><b>Domain</b></td>
                    <td><b>Action</b></td>
                    <td><b>URL</b></td>
                  </tr>
                  {list}
                </tbody></table>
                <p/>

                <button onClick={this.showAddModule}>Add Module</button>
                <ReactModal
                  isOpen={this.state.showAdd}
                  onRequestClose={() => this.closeAddModule(null)}
                  className="modal"
                  shouldCloseOnOverlayClick={false}
                  appElement={document.body}>

                  <h2>Add Module</h2>
                  <p/>
                  <form>
                    <label>Module:&nbsp;
                      <input type="text" ref={this.moduleInput} list="availableModules" required />
                      <datalist id="availableModules">{availableModules}</datalist>
                    </label>
                    <p/>
                    <label>Domain:&nbsp;
                        <input type="text" ref={this.domainInput} defaultValue=""/>
                    </label>
                    <p/>
                    <button onClick={() => this.closeAddModule("add")}>Add</button> &nbsp;
                    <button onClick={() => this.closeAddModule(null)}>Cancel</button>
                  </form>
                </ReactModal>
            </div>
            );
        };
    }

export default Home;