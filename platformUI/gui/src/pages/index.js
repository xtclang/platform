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

const postOptions = {
    method:  'post',
    headers: {'Content-Type':'text/html'},
    body:    {}
    };

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
                checkedApps : []
                };
        this.action = this.sendRequest.bind(this);

        this.showAddModule  = this.showAddModule.bind(this);
        this.closeAddModule = this.closeAddModule.bind(this);
        this.unregister     = this.unregister.bind(this);
        this.toggle         = this.toggle.bind(this);

        this.moduleInput = React.createRef();
        this.domainInput = React.createRef();
        }

    componentDidMount() {
        fetch('host/userId')
            .then(response => response.json())
            .then(name => this.setState(state => ({userId: name})));
        fetch('host/registeredApps')
            .then(response => response.json())
            .then(infos => this.setState(state =>
                ({registeredApps: infos, checkedApps: Array(infos.length).fill(false)})));
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

        const info   = this.state.registeredApps[ix];
        const domain = info.domain;
        const url    = info.url == null ? null : info.url;

        if (url == null)
            {
            // load application
            this.setState(state => ({loadingIndex: ix, loadingTicks: 0}));
            this.interval = setInterval(() => this.tick(ix), 500);

            const request = '/host/load?app=' + info.name + ',domain=' + domain;
            fetch(request, postOptions)
                .then(response => response.json())
                .then(data =>
                    {
                    if (data[0])
                        {
                        this.setInfo(ix, data[1], null);
                        }
                    else
                        {
                        this.setInfo(ix, null, data[1]);
                        }
                    })
                .finally(() => clearInterval(this.interval));
            }
        else
            {
            // unload application
            const request = '/host/unload/' + domain;
            fetch(request, postOptions);

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

    closeAddModule(command)
        {
        if (command == "add")
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

            var checkedApps = this.state.checkedApps;

            registeredApps.push(new AppInfo(moduleName, domain + '.' + this.state.userId + ".user"));
            checkedApps.push(false);

            this.setState(state => ({registeredApps: registeredApps, checkedApps: checkedApps, showAdd: false}));
            }
        else
            {
            this.setState(state => ({showAdd: false}));
            }
        }

    unregister()
        {
        const registeredOld = this.state.registeredApps;
        const registeredNew = [];
        const checkedOld    = this.state.checkedApps;
        const checkedNew    = [];

        for (var i = 0, c = registeredOld.length; i < c; i++)
            {
            if (checkedOld[i])
                {
                const info    = registeredOld[i];
                const request = '/host/unregister?app=' + info.name + ',domain=' + info.domain;
                fetch(request, postOptions);
                }
            else
                {
                checkedNew.push(false);
                registeredNew.push(registeredOld[i]);
                }
            }

        if (checkedNew.length != checkedOld.length)
            {
            this.setState(state => ({registeredApps: registeredNew, checkedApps: checkedNew}));
            }
        }

    toggle(ix)
        {
        var checks = this.state.checkedApps;
        checks[ix] = !checks[ix];
        this.setState({checkedApps: checks});
        }

    render()
        {
        const registeredApps   = this.state.registeredApps;
        const checkedApps      = this.state.checkedApps;
        const availableModules = this.state.availableModules.map((name, index) => <option key={index}>{name}</option>);
        let   list = [];

        for (var i = 0, c = registeredApps.length; i < c; i++)
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
                    <td><input id={'check-' + ix} type="checkbox" checked={checkedApps[ix]}
                        onChange={() => this.toggle(ix)} /></td>
                    <td>{info.name}</td>
                    <td>{info.domain}</td>
                    <td><input type="button" value={actionText}
                        onClick={() => this.action(ix)} /></td>
                    <td>{link}</td>
                </tr>
                );
            }

        return (
            <div>
                <h2>Welcome to XQIZ.IT portal</h2>
                <b>User:</b> {this.state.userId}

                <p/>
                <table>
                  <thead><tr>
                    <td><b></b></td>
                    <td><b>Module</b></td>
                    <td><b>Domain</b></td>
                    <td><b>Action</b></td>
                    <td><b>URL</b></td>
                  </tr></thead>
                  <tbody>
                    {list}
                  </tbody>
                </table>
                <p/>

                <button onClick={this.showAddModule}>Register Module</button>&nbsp;&nbsp;
                <button onClick={this.unregister}>Unregister Module</button>
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