namespace Common
{
    public interface IGUIShow
    {
        int  fontSize { get; set; }
        bool isShowGUI { get; set; }
        void ShowOrHide();
    }
}
