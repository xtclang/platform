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
    modules: (state) => state.modulesJSON,
    uploadURL: (state) => apiModule.defaults.baseURL + "/upload",
  },

  actions: {

    enhance() {
      delete this.modules['$type']
      for (const [name, module] of Object.entries(this.modules)) {
        var hasMissing = module.dependentModules.some(
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
      this.$q.loading.show();
      apiModule
        .get("/all")
        .then((response) => {
          this.modulesJSON = response.data;
          this.enhance();
        })
        .catch(() => {
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
    },

    deleteModule(moduleName) {
      this.$q.loading.show();
      apiModule
        .delete("/delete/" + moduleName)
        .then(() => {
          this.updateModules();
        })
        .catch(() => {
          this.$q.loading.hide();
          this.$q.notify({
            color: "negative",
            position: "top",
            message: "Could not delete the module",
            icon: "report_problem",
          });
        });
    },

    resolveModule(moduleName) {
      this.$q.loading.show();
      apiModule
        .post("/resolve/" + moduleName)
        .then(() => {
          this.updateModules();
        })
        .catch(() => {
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
});
