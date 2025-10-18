namespace ConsoleApplication;

public class Program
{
    public static void Main(string[] args)
    {
        Console.WriteLine("Hello from ConsoleApplication!");

#if TEST_BUILD
        Console.WriteLine("This is a TEST build");
#endif

#if DEBUG
        Console.WriteLine("Running in DEBUG mode");
#else
        Console.WriteLine("Running in RELEASE mode");
#endif

        Console.WriteLine($"Version: {typeof(Program).Assembly.GetName().Version}");
    }
}
