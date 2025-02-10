import ecstasy.text.Log;

/**
 * A host for a kernel module, which  is used simply as a holder for some basic information allowing
 * to simplify some APIs.
 */
const KernelHost(Directory homeDir, Directory buildDir)
        extends AppHost("", Null, homeDir, buildDir) {

    @Override
    Boolean active = True;

    @Override
    conditional Object activate(Boolean explicit, Log errors) = throw new Unsupported();

    @Override
    Boolean deactivate(Boolean explicit) = throw new Unsupported();

    @Override
    String toString() = $"Kernel module";

    @Override
    void close(Exception? e = Null) = throw new Unsupported();
}