import { defineStore } from "pinia";
import { apiModule } from "boot/axios";
import { useQuasar } from "quasar";

export const useModuleStore = defineStore("module", {
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
        .filter(m => m.moduleType=="Web")
        .map(m => m.name)
    },
  },

  actions: {

    enhance() {
      delete this.modules["$type"] // remove the metadata

      for (const module of Object.values(this.modules)) {
        var hasMissing = module.dependencies.some(
          (requiredModule) => !requiredModule.available
        );
        var hasIssues = (module.issues != undefined && module.issues.length > 0);
        module.displayInfo = {
          dependencies: {
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
        console.log(`DEV MODE: Adding mock modules data`);
        this.modulesJSON = {
          "bank.examples.org": {
            name: "bank.examples.org",
            isResolved: false,
            moduleType: "Db",
            issues: [],
            dependencies: [
              {name: "oodb.xtclang.org", available: true},
            ],
          },
          "bankStressTest.examples.org": {
            name: "bankStressTest.examples.org",
            isResolved: true,
            moduleType: "Web",
            issues: [],
            dependencies: [
              {name: "web.xtclang.org", available: true},
              {name: "bank.examples.org", available: true},
            ],
          },
        };
        this.enhance();
      } else {
         // fetch actual data
        this.$q.loading.show();
        apiModule
          .get("/all")
          .then(response => {
            this.modulesJSON = response.data;
            this.enhance();
          })
          .catch(error => {
            console.log(error.response);
            this.$q.notify({
              color: "negative", position: "top", icon: "report_problem",
              message: "Could not fetch modules",
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
          .then((response) => {
              this.updateModules();
            })
          .catch(error => {
            var response = error.response;
            var message;
            switch (response.status) {
            case 409: // Conflict
              message = "There are deployments that depend on this module:\n" +
                        response.data;
              break;

            case 404: // NotFound
              message = "The module is missing";
              break;

            default:
              message = "Failed to delete the module: " + response;
              break;
            }
            this.$q.notify({
              color: "negative", position: "top", icon: "report_problem",
              message: message,
            });
          })
          .finally(() => {
            this.$q.loading.hide();
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
          .catch(error => {
            console.log(error.response);
            this.$q.notify({
              color: "negative", position: "top", icon: "report_problem",
              message: "Could not resolve the module",
            });
          })
          .finally(() => {
            this.$q.loading.hide();
          });
      }
    },
  },
});