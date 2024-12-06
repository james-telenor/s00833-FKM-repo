drop proc INS_COMET_RES_AND_APP
go
CREATE PROCEDURE dbo.INS_COMET_RES_AND_APP
        @kurt_id                        numeric(12,0) = null,
        @res_app_indicator_id           smallint,
        @comm_purpose_id                numeric(12,0),
        @comm_shape_id                  smallint = null,
        @address_type_link_id           numeric(12,0) = null,
        @status                         varchar(15)  = null,
        @res_app_given_date             datetime = null,
        @source_origin_id               smallint,
        @address_type_id                smallint = null,
        @contact_role_id                numeric(12,0) = null,
--MBSS-6631
        @email_address                  varchar(320) = null,
        @phone_nbr_int_prefix           varchar(3) = null, 
        @phone_nbr_nat_part             varchar(50) = null,
        @phone_number_type_id           smallint = null,
--MBSS-6631
        @res_app_valid_from_date        datetime, 
        @res_app_valid_to_date          datetime = null,
        @info_reg_appl_name             varchar(12), 
        @info_reg_user_name             varchar(12) = null, 
        @info_reg_date                  datetime = null, 
        @res_and_app_id                 numeric(12,0) OUT,
        @out_err_code                   int OUT,
        @out_err_msg                    varchar(60) OUT,
        @address_link_id                   numeric(12,0) = null
with recompile
AS
/****************************************************************************************** 
   name   : INS_COMET_RES_AND_APP     
                                                      
   Author  : Meghana Kawari                                                                 
   comments : Insert it into RES_AND_APPROVAL table                                         
   History  : 
                                                                              
   <Change By>     < Date >     < Description >                                             
    Bipin Daga   16 June 2010   Changes done to check for adding genral 
          
                      or specific reservation and approval
    Bipin Daga   16 Aug 2010    Added out parameter for returning Error_code and
                                Err_msg.  
    Drupad Bhatt  02 APR 2015   removed trim function (for INC000000032252- PBI000000002122) 								
*******************************************************************************************/
DECLARE   @err_code                 int,
          @comm_purp_group_id       smallint,
          @master_id                numeric(12,0), 
          @var_add_type_link_id     numeric(12,0),
          @var_address_type_link_id numeric(12,0),
          @var_res_and_app_id       numeric(12,0),   
          @var_address_type_name    varchar(64),  
          @address_type_id_col      smallint,
          @var_address_type_id      smallint,        
          @far_id                   int,                      
          @address_street           varchar(256),     
  
          @address_postbox          varchar(30),   
          @postcode_id              varchar(30), 
          @postcode_name            varchar(50),  
          @cnt                      int,
          @var_contact_role_id      numeric(12,0),
          @error_message            varchar(60),
          @error_message1           varchar(60),
          @date                     datetime
              
SET       @error_message =  'insert operation failed in res_and_approval table',
          @error_message1 = ' Reservation already exist',
          @date = getdate()  
            
-- INC-347 
    if (@phone_nbr_nat_part = '' or @email_address='')
    begin
        select @out_err_code = 1,@out_err_msg  = 'Invalid parameter combination '
        return @out_err_code 
    end
-- INC-347     
                             
BEGIN
    CREATE TABLE #tmp_res_and_app (RES_AND_APP_ID numeric(12,0), 
                                   ADDRESS_TYPE_LINK_ID numeric(12,0) null, 
                                   ADDRESS_TYPE_ID smallint  null )
						
-- selecting comm_purp_group_id for the given comm_purpose          
    IF @comm_purpose_id IS NOT NULL
    BEGIN                                                           
        SELECT @comm_purp_group_id = COMM_PURP_GROUP_ID             
        FROM COMM_PURPOSE                                           
        WHERE COMM_PURPOSE_ID = @comm_purpose_id                    
    END                                                             
                                                             
       
-- selecting master_id for the given kurt_id                        
    IF @kurt_id IS NOT NULL                                         
    BEGIN                                                           
        SELECT @master_id = MASTER_ID   
                            
        FROM MASTER_CUSTOMER                                        
        WHERE KURT_ID = @kurt_id 
        IF @master_id IS NULL and @contact_role_id is null
        BEGIN
            SELECT @out_err_code = 1,@out_err_msg  = 'Invalid kurt_id '
            RETURN @out_err_code               
        END
    END     

    --MBSS-6631

    if @address_link_id is not null and @master_id is null and @contact_role_id is null 
    begin
        select
            @master_id = master_id,@contact_role_id = contact_role_id
        from address_link
        where
            address_link_id=@address_link_id
        and
            isnull(valid_to_date,'99991231') > getdate()
        and
            info_is_deleted = 'N'

    end
    if @address_link_id is null and (@email_address is not null or @phone_nbr_nat_part is not null)
    begin

        if @master_id is not null and @email_address is not null
        begin
            select @address_link_id = address_link_id
            from address_link al,email_address e
            where al.master_id=@master_id
            and e.address_type_link_id=al.address_type_link_id
            and e.email_address = @email_address
            and al.valid_to_date is null and al.preferred_address='Y' and al.info_is_deleted='N' and e.info_is_deleted='N'
            and comm_purpose_id = @comm_purpose_id
        end

        if @contact_role_id is not null and @email_address is not null
        begin
            select @address_link_id = address_link_id
            from address_link al,email_address e
            where al.contact_role_id=@contact_role_id
            and e.address_type_link_id=al.address_type_link_id
            and e.email_address = @email_address
            and al.valid_to_date is null and al.preferred_address='Y' and al.info_is_deleted='N' and e.info_is_deleted='N'
            and comm_purpose_id = @comm_purpose_id
        end

        if @address_link_id is not null
        begin
            select @res_and_app_id = res_and_app_id from res_and_approval where address_link_id=@address_link_id and res_app_indicator_id=@res_app_indicator_id 
            and comm_purpose_id=@comm_purpose_id and res_app_valid_to_date is null and info_is_deleted = 'N'
            if @res_and_app_id is not null return
        end
        if @address_link_id is null and @email_address is not null
        begin
            exec INS_COMET_EMAIL_ADDRESS 
                @address_type_id = @address_type_id,
                @address_source_id = 3,     
                @contact_role_id = @contact_role_id,
                @kurt_id = @kurt_id,
                @comm_purpose_id = @comm_purpose_id,
                @preferred_address = 1,
                @valid_from_date = @date,
                @recipient_confirmation_date = @date,
                @personal_address = 0,
                @email_address = @email_address,
                @info_reg_appl_name = @info_reg_appl_name,
                @info_reg_user_name = @info_reg_user_name,
                @info_reg_date = @info_reg_date,
                @address_type_link_id = @address_type_link_id out,
                @address_link_id = @address_link_id out,
                @out_err_code = @out_err_code out,
                @out_err_msg = @out_err_msg out
        end
        if @master_id is not null and @phone_nbr_nat_part is not null
        begin
            select @address_link_id = address_link_id
            from address_link al,phone_number p
            where al.master_id=@master_id
            and p.address_type_link_id=al.address_type_link_id
            and p.phone_nbr_nat_part = @phone_nbr_nat_part
            and isnull(p.phone_nbr_int_prefix,'') = isnull(@phone_nbr_int_prefix,'')
            and al.valid_to_date is null and al.preferred_address='Y' and al.info_is_deleted='N' and p.info_is_deleted='N'
            and comm_purpose_id = @comm_purpose_id
        end

        if @contact_role_id is not null and @phone_nbr_nat_part is not null
        begin
            select @address_link_id = address_link_id
            from address_link al,phone_number p
            where al.contact_role_id=@contact_role_id
            and p.address_type_link_id=al.address_type_link_id
            and p.phone_nbr_nat_part = @phone_nbr_nat_part
            and isnull(p.phone_nbr_int_prefix,'') = isnull(@phone_nbr_int_prefix,'')
            and al.valid_to_date is null and al.preferred_address='Y' and al.info_is_deleted='N' and p.info_is_deleted='N'
            and comm_purpose_id = @comm_purpose_id
        end

        if @address_link_id is not null
        begin
            select @res_and_app_id = res_and_app_id from res_and_approval where address_link_id=@address_link_id and res_app_indicator_id=@res_app_indicator_id 
            and comm_purpose_id=@comm_purpose_id and res_app_valid_to_date is null and info_is_deleted = 'N'
            if @res_and_app_id is not null return
        end
        if @address_link_id is null and @phone_nbr_nat_part is not null
        begin

            exec INS_COMET_PHONE_NUMBER
                @address_type_id = @address_type_id,
                @address_source_id = 3,     
                @contact_role_id = @contact_role_id,
                @kurt_id = @kurt_id,
                @comm_purpose_id = @comm_purpose_id,
                @preferred_address = 1,
                @valid_from_date = @date,
                @recipient_confirmation_date = @date,
                @personal_address = 0,
                @phone_number_type_id = @phone_number_type_id,
                @phone_nbr_int_prefix = @phone_nbr_int_prefix,
                @phone_nbr_nat_part = @phone_nbr_nat_part,
                @info_reg_appl_name = @info_reg_appl_name,
                @info_reg_user_name = @info_reg_user_name,
                @info_reg_date = @info_reg_date,
                @address_type_link_id = @address_type_link_id out,
                @address_link_id = @address_link_id out,
                @out_err_code = @out_err_code out,
                @out_err_msg = @out_err_msg out
        end

    end --MBSS-6631

    -- EKI if @address_link_id is set fetch @address_type_link_id from address_link
    if @address_link_id is not null
    begin
        select @address_type_link_id=address_type_link_id
        from address_link
        where
            address_link_id=@address_link_id
        and
            isnull(valid_to_date,'99991231') > getdate()
        and
            info_is_deleted = 'N'
    end
    if @address_type_link_id is not null and @address_link_id is null -- @address_link_id not set find / create an address_link if necessary (due to mixture of old new COMET codelines)
    begin
    
        if @master_id is not null
        begin
            
            select @address_link_id = address_link_id
            from
                address_link where address_type_link_id = @address_type_link_id
            and
                master_id=@master_id
            and 
                comm_purpose_id = @comm_purpose_id    
            and
                isnull(valid_to_date,'99991231') > getdate()
            and
                info_is_deleted = 'N'
        end
        
        if @contact_role_id is not null
        begin
            select @address_link_id = address_link_id
            from
                address_link where address_type_link_id = @address_type_link_id
            and 
                contact_role_id = @contact_role_id
            and
                comm_purpose_id = @comm_purpose_id        
            and
                isnull(valid_to_date,'99991231') > getdate()
            and
                info_is_deleted = 'N'
        end
        
            
        if @address_link_id is null
        begin
            insert address_link(address_type_link_id,contact_role_id,comm_purpose_id,comm_purp_group_id,master_id,preferred_address,valid_from_date,
                        info_reg_user_name,info_reg_appl_name,info_reg_date,info_is_deleted)
            values(@address_type_link_id,@contact_role_id,@comm_purpose_id,@comm_purp_group_id,@master_id,'Y',@res_app_valid_from_date,
                        @info_reg_user_name,@info_reg_appl_name,getdate(),'N')
            select @address_link_id = @@identity
            
            -- select @address_type_id = address_type_id from address_type_link where address_type_link_id = @address_type_link_id

            if @master_id is not null and @address_link_id is not null
            begin
                update address_link set preferred_address='N',info_chg_appl_name=@info_reg_appl_name,INFO_CHG_DATE=getdate(),info_chg_user_name=@info_reg_user_name
                from address_link al (index RELATIONSHIP_101_FK),address_type_link atl where al.address_type_link_id = atl.address_type_link_id
                and al.master_id=@master_id and atl.address_type_id=@address_type_id 
                and isnull(al.valid_to_date,'99991231') > getdate() 
                and al.info_is_deleted = 'N' and atl.info_is_deleted = 'N' and al.preferred_address='Y'
                and address_link_id != @address_link_id
            end
            if @contact_role_id is not null and @address_link_id is not null
            begin
                update address_link set preferred_address='N',info_chg_appl_name=@info_reg_appl_name,INFO_CHG_DATE=getdate(),info_chg_user_name=@info_reg_user_name
                from address_link al (index RELATIONSHIP_104_FK),address_type_link atl where al.address_type_link_id = atl.address_type_link_id
                and al.contact_role_id=@contact_role_id and atl.address_type_id=@address_type_id 
                and isnull(al.valid_to_date,'99991231') > getdate() 
                and al.info_is_deleted = 'N' and atl.info_is_deleted = 'N' and al.preferred_address='Y'
                and address_link_id != @address_link_id        
            end
        
        end
        
    
    end
    
    
-- selecting ADDRESS_TYPE_ID for the given ADDRESS_TYPE_LINK_ID     
    IF @address_type_link_id IS NOT NULL
    BEGIN
		SELECT @var_address_type_id = ADDRESS_TYPE_ID                      
        FROM  ADDRESS_TYPE_LINK                                             
        WHERE ADDRESS_TYPE_LINK_ID = @address_type_link_id   
        --SELECT @var_address_type_id = @address_type_id 
    END    
-- selecting ADDRESS_TYPE_ID for the given @address_type_id      
    IF @address_type_id  IS NULL
    BEGIN
        SELECT @address_type_id = @var_address_type_id 
    END       
    IF @contact_role_id IS NOT NULL
    BEGIN
        SELECT @var_contact_role_id = CONTACT_ROLE_ID 
        FROM  CONTACT_ROLE 
        WHERE CONTACT_ROLE_ID = @contact_role_id
        IF  @var_contact_role_id IS NULL and @kurt_id IS NULL
        BEGIN
            SELECT @out_err_code = 1,
                   @out_err_msg  = 'Invalid contact_role_id'
            RETURN @out_err_code               
        END
        
    END

-- Checks the existence of RES_AND_APPROVAL in CDC if master_id is NOT NULL 
    IF @master_id IS NOT NULL     --IF kurt_id is not null                             
               
    BEGIN  
    	INSERT INTO #tmp_res_and_app  (RES_AND_APP_ID,ADDRESS_TYPE_LINK_ID,address_type_id) 
        SELECT r.RES_AND_APP_ID ,
               ADDRESS_TYPE_LINK_ID,                                    
               address_type_id

        FROM   RES_AND_APPROVAL r                                              
        WHERE  r.MASTER_ID = @master_id                                        
        AND    r.RES_APP_INDICATOR_ID = @res_app_indicator_id                  
        AND    r.COMM_PURPOSE_ID = @comm_purpose_id                            
        AND    ISNULL(r.COMM_SHAPE_ID,0) = ISNULL(@comm_shape_id,0)            
        AND    ISNULL(r.STATUS,'') = ISNULL(@status,'')
        AND    r.SOURCE_ORIGIN_ID = @source_origin_id
                          
        AND    ISNULL(r.ADDRESS_TYPE_ID,0) = ISNULL(@address_type_id,0)        
        AND    (r.RES_APP_VALID_TO_DATE > GETDATE()
                OR r.RES_APP_VALID_TO_DATE is NULL)                             
    END        
                                                                                                                                          
    IF @contact_role_id IS NOT NULL                                                                        
    BEGIN                                                                     
        INSERT INTO #tmp_res_and_app  (RES_AND_APP_ID,ADDRESS_TYPE_LINK_ID,address_type_id) 
        SELECT r.RES_AND_APP_ID ,    
               ADDRESS_TYPE_LINK_ID,
               address_type_id
        FROM   RES_AND_APPROVAL r        
        WHERE  r.CONTACT_ROLE_ID = @contact_role_id                     
        AND    r.RES_APP_INDICATOR_ID = @res_app_indicator_id           
        AND    r.COMM_PURPOSE_ID = @comm_purpose_id 
                    
        AND    ISNULL(r.COMM_SHAPE_ID,0) = ISNULL(@comm_shape_id,0)     
        AND    ISNULL(r.STATUS,'') = ISNULL(@status,'')
        AND    r.SOURCE_ORIGIN_ID = @source_origin_id                   
        AND    ISNULL(r.ADDRESS_TYPE_ID,0) = ISNULL(@address_type_id,0) 
        AND    (r.RES_APP_VALID_TO_DATE > GETDATE()
                OR r.RES_APP_VALID_TO_DATE is NULL)                                                                        
    END                               
                                 

-- record is already present in CDC check                               
SELECT @cnt = COUNT(*) FROM #tmp_res_and_app
IF @cnt > 0 --records are present in RES_AND_APPROVAL                                                 
            
BEGIN
BEGIN TRANSACTION                                                       
--CHECK FOR ADDRESS_TYPE_LINK_ID                                                         
SELECT @cnt = COUNT(*) FROM #tmp_res_and_app
WHERE ADDRESS_TYPE_LINK_ID IS NOT NULL

--CHECK 1
/*While input parameter address_type_link_id is null AND  
No address_type_link_id for kurt_id/contact_role_id is present 
in RES_AND_APPROVAL with appropriate address parameters*/
IF @address_type_link_id IS NULL AND @cnt = 0       
                    
BEGIN                                                                   
    SELECT @res_and_app_id = RES_AND_APP_ID
    FROM #tmp_res_and_app 
    WHERE ADDRESS_TYPE_LINK_ID IS NULL
                                         
    SELECT @out_err_code  = 1,
           @out_err_msg   = @error_message1
    ROLLBACK TRANSACTION       
    RETURN @out_err_code                                                    
	END--END OF CHECK 1    
  --CHECK 2                  
/*While input parameter ad
dress_type_link_id is null AND  
address_type_link_id for kurt_id/contact_role_id is present 
in RES_AND_APPROVAL with appropriate address parameters*/                           
IF @address_type_link_id IS NULL AND @cnt > 0           
BEGIN      
    IF @address_type_id  IS NOT NULL
    BEGIN
        SELECT  @var_res_and_app_id = res_and_app_id 
        FROM #tmp_res_and_app 
        WHERE ADDRESS_TYPE_LINK_ID IS NULL
        AND address_type_id = @address_type_id
        
        IF @var_res_and_app_id IS NOT NULL                      
        BEGIN
            SELECT @res_and_app_id = @var_res_and_app_id, 
                   @out_err_code  = 1,
                   @out_err_msg   = @error_message1                            
            ROLLBACK TRANSACTION  
            RETURN @out_err_code                                
        END
        
    END
    goto CreateResApp                                   
END--END OF CHECK 2                                     
  --CHECK 3      
/*While input parameter
 address_type_link_id is not null AND  
No address_type_link_id for kurt_id/contact_role_id is present
in RES_AND_APPROVAL with appropriate address parameters */                                       
IF @address_type_link_id IS NOT NULL AND @cnt = 0     
  
BEGIN                                                   
    goto CreateResApp                                   
END --END OF CHECK 3                                    
  --CHECK 4                         
/*While input parameter address_type_link_id
 is not null AND  
address_type_link_id for kurt_id/contact_role_id is present
in RES_AND_APPROVAL with appropriate address parameters */                      
IF @address_type_link_id IS NOT NULL AND @cnt > 0       
BEGIN

    SELECT  @var_res_and_app_id = res_and_app_id 
    FROM #tmp_res_and_app 
    WHERE ADDRESS_TYPE_LINK_ID = @address_type_link_id 

    IF @var_res_and_app_id IS NOT NULL                      
    BEGIN
    /*While input parameter address_type_link_id is same as   
    address_type_l
ink_id present for kurt_id/contact_role_id 
    in RES_AND_APPROVAL with appropriate address parameters*/
        SELECT @res_and_app_id = @var_res_and_app_id, 
               @out_err_code  = 1,
               @out_err_msg   = @error_message1            
                
        ROLLBACK TRANSACTION  
        RETURN @out_err_code                            
    END
    ELSE                                                
    BEGIN
    /*While input parameter address_type_link_id is and   
    address_type
_link_id present for kurt_id/contact_role_id 
    in RES_AND_APPROVAL has same address parameter values */
        SELECT @var_address_type_name = UPPER(address_type_name) 
        FROM  CDC_ADDRESS_TYPE                                   
        WHERE ADDRESS_TYPE_ID = @var_address_type_id             
    
        IF @var_address_type_name = 'ADDRESS'                    
        BEGIN 
            SELECT @far_id = FAR_ID  ,                           
                   @address_street =ADDRESS_STREET ,

                   @address_postbox = ADDRESS_POSTBOX,           
                   @postcode_id = POSTCODE_ID ,                  
                   @postcode_name = POSTCODE_NAME                
            FROM ADDRESS                                 
        
            WHERE ADDRESS_TYPE_LINK_ID = @address_type_link_id   
    
            SELECT @var_res_and_app_id = t.RES_AND_APP_ID
            FROM #tmp_res_and_app t, ADDRESS a                   
            WHERE  t.ADDRESS_TYPE_LINK_ID =a.ADDRESS_TYPE_LINK_ID
            AND    isnull(@far_id,0)                             = isnull(FAR_ID,0)  
            AND    UPPER(LTRIM(RTRIM(isnull(a.ADDRESS_STREET,'~')))) =UPPER(LTRIM(RTRIM(isnull(@address_street,'~'))))   
            AND    UPPER(LTRIM(RTRIM(isnull(a.ADDRESS_POSTBOX,'~')))) =UPPER(LTRIM(RTRIM(isnull(@address_postbox,'~'))))
            AND    UPPER(LTRIM(RTRIM(isnull(a.POSTCODE_ID,'~')))) =UPPER(LTRIM(RTRIM(isnull(@postcode_id,'~'))))
            AND    UPPER(LTRIM(RTRIM(isnull(a.POSTCODE_NAME,'~')))) =UPPER(LTRIM(RTRIM(isnull(@postcode_name,'~'))))     
    
            IF @var_res_and_app_id IS NULL 
            BEGIN
                goto CreateResApp
            END
            ELSE                           
            BEGIN 
      
          SELECT @res_and_app_id = @var_res_and_app_id, 
                       @out_err_code  = 1,
                       @out_err_msg   = @error_message1                            
                ROLLBACK TRANSACTION  
                RETURN @out_err_code                          
            END                                               
        END 
                                                              
        IF @var_address_type_name = 'PHONE'            
        BEGIN
            SELECT @phone_nbr_nat_part= PHONE_NBR_NAT_PART,    
                   @phone_nbr_int_prefix = PHONE_NBR_INT_PREFIX
            FROM PHONE_NUMBER                                  
            WHERE ADDRESS_TYPE_LINK_ID = @address_type_link_id 
    
         
   SELECT @var_res_and_app_id = t.RES_AND_APP_ID
            FROM #tmp_res_and_app t, PHONE_NUMBER p            
            WHERE  t.ADDRESS_TYPE_LINK_ID =p.ADDRESS_TYPE_LINK_ID                                                                 
           
         -- AND   UPPER(LTRIM(RTRIM(isnull(p.PHONE_NBR_NAT_PART,'~')))) = UPPER(LTRIM(RTRIM(isnull(@phone_nbr_nat_part,'~'))))  
            AND   isnull(p.PHONE_NBR_NAT_PART,'~') = isnull(@phone_nbr_nat_part,'~')                    --(for INC000000032252- PBI000000002122 trim function removed from here 02-APR-2015)   
            AND   UPPER(LTRIM(RTRIM(isnull(p.PHONE_NBR_INT_PREFIX,'~')))) = UPPER(LTRIM(RTRIM(isnull(@phone_nbr_int_prefix,'~') )))                      
    
            IF @var_res_and_app_id IS NULL     
            BEGIN
                goto CreateResApp
            END
            ELSE                               
            BEGIN
                SELECT @res_and_app_id = @var_res_and_app_id,                                                                  
                       @out_err_code  = 1,
                       @out_err_msg   = @error_message1                            
                ROLLBACK TRANSACTION  
                RETURN @out_err_code       
            END
        END 
                                          
        IF @var_address_type_name = 'EMAIL ADDRESS'     
        BEGIN 
            SELECT  @email_address = EMAIL_ADDRESS    
  
            FROM EMAIL_ADDRESS                          
            WHERE ADDRESS_TYPE_LINK_ID = @address_type_link_id     
                                                                   
            SELECT @var_res_and_app_id = t.RES_AND_APP_ID
 
           FROM #tmp_res_and_app t, EMAIL_ADDRESS e
            WHERE  t.ADDRESS_TYPE_LINK_ID =e.ADDRESS_TYPE_LINK_ID  
            AND   UPPER(LTRIM(RTRIM(isnull(e.EMAIL_ADDRESS,'~')))) = UPPER(LTRIM(RTRIM(isnull(@email_address,'~'))))                   
                  
                                                   
            IF @var_res_and_app_id is null         
            BEGIN
                goto CreateResApp                  
            END  
            ELSE                            
       
            BEGIN
                SELECT @res_and_app_id = @var_res_and_app_id,   
                       @out_err_code  = 1,
                       @out_err_msg   = @error_message1                            
                ROLLBACK TRANSACTION 
 
                RETURN @out_err_code
            END
        END
    END                            

END--END OF CHECK 4  
COMMIT TRANSACTION
RETURN @err_code

END--END OF IF   

ELSE 
BEGIN 
BEGIN TRANSACTION
    goto CreateResApp
    COMMIT TRANSACTION
    RETURN @err_code
END 
                                   
CreateResApp:   
-- EKI terminate any conflicting reservations/approvals

        if @var_address_type_id = 3 -- 'EMAIL ADDRESS' 
        begin
            SELECT  @email_address = EMAIL_ADDRESS      
            FROM EMAIL_ADDRESS                          
            WHERE ADDRESS_TYPE_LINK_ID = @address_type_link_id  
            
        update RES_AND_APPROVAL
        set RES_APP_VALID_TO_DATE = getdate(),
            INFO_CHG_USER_NAME = @info_reg_user_name,    
            INFO_CHG_APPL_NAME = @info_reg_appl_name,
            INFO_CHG_DATE = getdate()
        from RES_AND_APPROVAL r,email_address e
        where
            (
                (isnull(r.master_id,0) = isnull(@master_id,0)) and
                (isnull(r.contact_role_id,0) = isnull(@contact_role_id,0))
            ) and r.comm_purpose_id = @comm_purpose_id and
            -- address_type_link_id = @address_type_link_id and @address_type_link_id is not null and

            r.address_type_link_id = e.address_type_link_id and e.email_address = @email_address and
            r.res_app_indicator_id != @res_app_indicator_id and
            r.info_is_deleted = 'N' and
            e.info_is_deleted = 'N' and
            isnull(r.res_app_valid_to_date,'99991231') > getdate() 
            
        end
        
        if @var_address_type_id = 2 -- 'PHONE' 
        begin
        
            SELECT @phone_nbr_nat_part= PHONE_NBR_NAT_PART,    
                  @phone_nbr_int_prefix = PHONE_NBR_INT_PREFIX
            FROM PHONE_NUMBER                                  
            WHERE ADDRESS_TYPE_LINK_ID = @address_type_link_id 
            
        update RES_AND_APPROVAL
        set RES_APP_VALID_TO_DATE = getdate(),
            INFO_CHG_USER_NAME = @info_reg_user_name,    
            INFO_CHG_APPL_NAME = @info_reg_appl_name,
            INFO_CHG_DATE = getdate()
        from RES_AND_APPROVAL r,phone_number p
        where
            (
                (isnull(r.master_id,0) = isnull(@master_id,0)) and
                (isnull(r.contact_role_id,0) = isnull(@contact_role_id,0))
            ) and
            r.comm_purpose_id = @comm_purpose_id and
            -- address_type_link_id = @address_type_link_id and @address_type_link_id is not null and
            r.address_type_link_id = p.address_type_link_id and 
            p.PHONE_NBR_NAT_PART = @phone_nbr_nat_part and
            isnull(p.PHONE_NBR_INT_PREFIX,'') = isnull(@phone_nbr_int_prefix,'') and
            r.res_app_indicator_id != @res_app_indicator_id and
            r.info_is_deleted = 'N' and
            p.info_is_deleted = 'N' and
            isnull(r.res_app_valid_to_date,'99991231') > getdate()             
        end
        
-- end EKI terminate any conflicting reservations/approvals
     if @address_link_id is not null 
     begin                
        INSERT INTO RES_AND_APPROVAL(MASTER_ID,RES_APP_INDICATOR_ID,COMM_PURPOSE_ID,COMM_PURP_GROUP_ID,COMM_SHAPE_ID,ADDRESS_TYPE_LINK_ID,ADDRESS_LINK_ID,STATUS,RES_APP_GIVEN_DATE,
        SOURCE_ORIGIN_ID,ADDRESS_TYPE_ID,CONTACT_ROLE_ID,RES_APP_VALID_FROM_DATE,RES_APP_VALID_TO_DATE,INFO_REG_USER_NAME,INFO_REG_APPL_NAME,INFO_REG_DATE,INFO_IS_DELETED          
        )   
        select
            @master_id,@res_app_indicator_id,@comm_purpose_id,@comm_purp_group_id,    
-- New code for MBSS-2323
            case 
                when @comm_shape_id is null and @address_type_id = 1 then 2 -- post
                when @comm_shape_id is null and @address_type_id = 2 then 1 -- tale
                when @comm_shape_id is null and @address_type_id = 3 then 4 -- email
                else @comm_shape_id 
            end ,          
-- MBSS-2323
            @address_type_link_id,@address_link_id,@status,@res_app_given_date,@source_origin_id,      
            @address_type_id,   
            @contact_role_id,@res_app_valid_from_date,@res_app_valid_to_date,@info_reg_user_name,@info_reg_appl_name,ISNULL(@info_reg_date,GETDATE()),'N'
            where not exists (select 1 from RES_AND_APPROVAL where ADDRESS_LINK_ID = @address_link_id and isnull(RES_APP_VALID_TO_DATE,'99991231') > getdate() 
            and info_is_deleted = 'N' and RES_APP_INDICATOR_ID = @res_app_indicator_id
--MBSS-6631
            -- and comm_purpose_id = 1 IAH-3257
            and comm_purpose_id = @comm_purpose_id -- IAH-3257
--MBSS-6631 
            )
     end

     if @address_link_id is null and @master_id is not null
     begin
        INSERT INTO RES_AND_APPROVAL(MASTER_ID,RES_APP_INDICATOR_ID,COMM_PURPOSE_ID,COMM_PURP_GROUP_ID,COMM_SHAPE_ID,ADDRESS_TYPE_LINK_ID,ADDRESS_LINK_ID,STATUS,RES_APP_GIVEN_DATE,
        SOURCE_ORIGIN_ID,ADDRESS_TYPE_ID,CONTACT_ROLE_ID,RES_APP_VALID_FROM_DATE,RES_APP_VALID_TO_DATE,INFO_REG_USER_NAME,INFO_REG_APPL_NAME,INFO_REG_DATE,INFO_IS_DELETED          
        )     
         select
            @master_id,@res_app_indicator_id,@comm_purpose_id,@comm_purp_group_id,    
-- New code for MBSS-2323
            case 
                when @comm_shape_id is null and @address_type_id = 3 then 4 -- email
                -- INC0011716
                when @comm_shape_id is null and @address_type_id = 2 then 1 -- TM
				when @comm_shape_id is null and @address_type_id = 1 then 2 -- DM
                -- INC0011716
                else @comm_shape_id 
            end ,          
-- MBSS-2323
            @address_type_link_id,@address_link_id,@status,@res_app_given_date,@source_origin_id,       
            -- INC0011716
            null,
            -- INC0011716    
            @contact_role_id,@res_app_valid_from_date,@res_app_valid_to_date,@info_reg_user_name,@info_reg_appl_name,ISNULL(@info_reg_date,GETDATE()),'N'
            where not exists (select 1 from RES_AND_APPROVAL where master_id=@master_id and isnull(RES_APP_VALID_TO_DATE,'99991231') > getdate() 
            and info_is_deleted = 'N' and RES_APP_INDICATOR_ID = @res_app_indicator_id 
--MBSS-6631
            -- and comm_purpose_id = 1 IAH-3257
            and comm_purpose_id = @comm_purpose_id -- IAH-3257
--MBSS-6631 
-- MBSS-11177
            and source_origin_id <> 1 -- 1 == brønnøysund,comet can only register @source_origin_id <> 1
-- MBSS-11177
            and comm_shape_id =             
            case 
                when @comm_shape_id is null and @address_type_id = 3 then 4 -- email
                -- INC0011716
                when @comm_shape_id is null and @address_type_id = 2 then 1 -- TM
				when @comm_shape_id is null and @address_type_id = 1 then 2 -- DM
                -- INC0011716
                else @comm_shape_id 
            end)
     end

     if @address_link_id is null and @contact_role_id is not null
     begin
        INSERT INTO RES_AND_APPROVAL(MASTER_ID,RES_APP_INDICATOR_ID,COMM_PURPOSE_ID,COMM_PURP_GROUP_ID,COMM_SHAPE_ID,ADDRESS_TYPE_LINK_ID,ADDRESS_LINK_ID,STATUS,RES_APP_GIVEN_DATE,
        SOURCE_ORIGIN_ID,ADDRESS_TYPE_ID,CONTACT_ROLE_ID,RES_APP_VALID_FROM_DATE,RES_APP_VALID_TO_DATE,INFO_REG_USER_NAME,INFO_REG_APPL_NAME,INFO_REG_DATE,INFO_IS_DELETED          
        )     
         select
            @master_id,@res_app_indicator_id,@comm_purpose_id,@comm_purp_group_id,    
-- New code for MBSS-2323
            case 
                when @comm_shape_id is null and @address_type_id = 3 then 4 -- email
                -- INC0011716
                when @comm_shape_id is null and @address_type_id = 2 then 1 -- TM
				when @comm_shape_id is null and @address_type_id = 1 then 2 -- DM
                -- INC0011716
                else @comm_shape_id 
            end ,          
-- MBSS-2323
            @address_type_link_id,@address_link_id,@status,@res_app_given_date,@source_origin_id,       
            -- INC0011716
            null,
            -- INC0011716    
            @contact_role_id,@res_app_valid_from_date,@res_app_valid_to_date,@info_reg_user_name,@info_reg_appl_name,ISNULL(@info_reg_date,GETDATE()),'N'
            where not exists (select 1 from RES_AND_APPROVAL where contact_role_id=@contact_role_id and isnull(RES_APP_VALID_TO_DATE,'99991231') > getdate() 
            and info_is_deleted = 'N' and RES_APP_INDICATOR_ID = @res_app_indicator_id         
--MBSS-6631
            -- and comm_purpose_id = 1 IAH-3257
            and comm_purpose_id = @comm_purpose_id -- IAH-3257
--MBSS-6631 
-- MBSS-11177
            and source_origin_id <> 1 -- 1 == brønnøysund,comet can only register @source_origin_id <> 1
-- MBSS-11177
            and comm_shape_id =             
            case 
                when @comm_shape_id is null and @address_type_id = 3 then 4 -- email
                -- INC0011716
                when @comm_shape_id is null and @address_type_id = 2 then 1 -- TM
				when @comm_shape_id is null and @address_type_id = 1 then 2 -- DM
                -- INC0011716
                else @comm_shape_id 
            end)
        end
  


                                             
        SELECT @err_code = @@error           
        IF @err_code <> 0                    
        BEGIN    
                            
            SELECT @out_err_code  = @err_code,
            @out_err_msg   = @error_message                           
            ROLLBACK TRANSACTION  
            RETURN @err_code                 
        END                
                  
   -- get the resp_and_app_id from the res_and_approval table     
        SELECT @res_and_app_id = @@identity ,
               @out_err_code   = 0,
               @out_err_msg    = 'Reservation Created successfully'

         COMMIT TRANSACTION 
END
GO
sp_procxmode 'dbo.INS_COMET_RES_AND_APP', 'Unchained'
GO
grant exec on INS_COMET_RES_AND_APP to comet_group
go
