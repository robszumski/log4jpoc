import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public class MyExample {
    private static final Logger logger = LogManager.getLogger(MyExample.class);

    public static void main(String[] args) {
        logger.error("${env:SECRET_VALUE:-:}");
        try 
        {
           Thread.sleep(Long.MAX_VALUE);
        } 
        catch(InterruptedException e)
        {
           // this part is executed when an exception (in this example InterruptedException) occurs
        }
    }
}
