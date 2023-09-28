import { defineStore } from 'pinia';
import { apiModule } from "boot/axios";
import { useQuasar } from "quasar";

export const useModuleStore = defineStore('module', {
  state: () => ({
    modulesJSON: [],
    modulesMap: {},
    $q: useQuasar()
  }),

  getters: {
    uploadURL     : ()      => apiModule.defaults.baseURL + "/upload",
    modules       : (state) => state.modulesJSON,
    moduleNames   : (state) => Object.keys(state.modulesJSON),
    webModuleNames: (state) => {
      return Object.values(state.modulesJSON)
        .filter(m => m.isWebModule)
        .map(m => m.name)
    },
  },

  actions: {

    enhance() {
      delete this.modules['$type']
      for (const [name, module] of Object.entries(this.modules)) {
        var hasMissing = module.dependents.some(
          (dependentModule) => !dependentModule.available
        );
        var hasIssues = (module.issues != undefined && module.issues.length > 0);
        this.modules[name].displayInfo = {
          deps: {
            "icon": hasMissing ? "warning" : "verified",
            "displayClass": hasMissing ? "text-negative" : "text-positive",
            "displayText": hasMissing ? "Missing dependencies" : "All dependencies available",
          },
          issues: {
            "icon": hasIssues ? "warning" : module.isResolved ? "verified" : "inventory",
            "displayClass": hasIssues ? "text-negative" : (module.isResolved ? "text-positive" : "text-warning"),
            "displayText": hasIssues ? "Issues found" : (module.isResolved ? "Resolved" : "Not resolved yet"),
            "expandable": hasIssues
          },
        }
      }
    },

    updateModules() {
      if (process.env.DEV) {
        /*
         * mock data for local testing
         */
        console.log(`DEV MODE: Adding mock modules data`);
        this.modulesJSON = {
          "bank.examples.org": {
            name: "bank.examples.org",
            isResolved: false,
            isWebModule: false,
            issues: [],
            dependents: [
              { name: "oodb.xtclang.org", available: true},
            ],
          },
          "bankStressTest.examples.org": {
            name: "bankStressTest.examples.org",
            isResolved: true,
            isWebModule: true,
            issues: [],
            dependents: [
              { name: "web.xtclang.org", available: true},
              { name: "bank.examples.org", available: true },
            ],
          },
        };
        this.enhance();

      } else {
        /*
         * fetch actual data
         */
        this.$q.loading.show();
        apiModule
          .get("/all")
          .then((response) => {
            this.modulesJSON = response.data;
            this.enhance();
          })
          .catch((error) => {
            console.log(error.toJSON());
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not fetch modules",
              icon: "report_problem",
            });
          })
          .finally(() => {
            this.$q.loading.hide();
          });
      }
    },

    deleteModule(moduleName) {
      if (process.env.DEV) {
        this.$q.notify({
          color: "info",
          position: "top",
          message: "Operation not available in dev mode",
          icon: "info",
        });
      } else {
        this.$q.loading.show();
        apiModule
          .delete("/delete/" + moduleName)
          .then(() => {
            this.updateModules();
          })
          .catch((error) => {
            console.log(error.toJSON());
            this.$q.loading.hide();
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not delete the module",
              icon: "report_problem",
            });
          });
      }
    },

    resolveModule(moduleName) {
      if (process.env.DEV) {
        this.$q.notify({
          color: "info",
          position: "top",
          message: "Operation not available in dev mode",
          icon: "info",
        });
      } else {
        this.$q.loading.show();
        apiModule
          .post("/resolve/" + moduleName)
          .then(() => {
            this.updateModules();
          })
          .catch((error) => {
            console.log(error.toJSON());
            this.$q.loading.hide();
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not resolve the module",
              icon: "report_problem",
            });
          });
      }
    },
  },
});